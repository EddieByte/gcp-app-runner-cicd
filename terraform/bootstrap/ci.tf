# -----------------------------------------------------------------------------
# CI/CD identity: Workload Identity Federation for GitHub Actions
#
# The GCP equivalent of an AWS IAM OIDC provider + role trust policy.
# GitHub issues a short-lived OIDC token per job; Google's STS exchanges it for
# short-lived credentials of a service account. No keys are ever created (and
# our org policy forbids SA keys anyway).
#
# Lives in bootstrap because the pool is a project-wide singleton shared by
# every environment.
#
# Separation of duties (one identity per pipeline job):
#   builder  - push images to Artifact Registry        (any release tag)
#   deployer - deploy Cloud Run, one SA per environment (created in envs/*,
#              bound to "dev" or "prod" tags only)
#   scanner  - read-only, for the weekly Trivy rescan   (scheduled runs on main)
#
# Docs: https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines
#       https://docs.github.com/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect
# -----------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub Actions"
  description               = "OIDC federation for ${var.github_repository}"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Claims from GitHub's token -> attributes we can write IAM rules against.
  # `attribute.channel` condenses "which repo, and what kind of run" into one
  # value so each service account can be bound to exactly one channel:
  #   <repo>:dev   tag dev-vX.Y.Z
  #   <repo>:prod  tag vX.Y.Z
  #   <repo>:scan  run on the scan branch (weekly rescan)
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.actor"      = "assertion.actor"
    "attribute.channel"    = <<-CEL
      assertion.repository + ':' + (
        assertion.ref.startsWith('refs/tags/dev-v') ? 'dev' :
        assertion.ref.startsWith('refs/tags/v') ? 'prod' :
        assertion.ref == 'refs/heads/${var.scan_branch}' ? 'scan' : 'none')
    CEL
  }

  # Hard gate: tokens from any other repository are rejected outright, even
  # before IAM bindings are evaluated (forks, other repos in the org, etc.).
  attribute_condition = "assertion.repository == '${var.github_repository}'"
}

locals {
  wif_principal_prefix = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.channel/${var.github_repository}"
}

# --- builder: push images only ------------------------------------------------
resource "google_service_account" "ci_builder" {
  account_id   = "ci-builder"
  display_name = "CI image builder"
  description  = "GitHub Actions: pushes release images to Artifact Registry."
}

resource "google_project_iam_member" "ci_builder" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.ci_builder.email}"
}

resource "google_service_account_iam_member" "ci_builder_wif" {
  for_each           = toset(["dev", "prod"]) # any release tag may build
  service_account_id = google_service_account.ci_builder.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.wif_principal_prefix}:${each.value}"
}

# --- scanner: read-only -------------------------------------------------------
resource "google_service_account" "ci_scanner" {
  account_id   = "ci-scanner"
  display_name = "CI security scanner"
  description  = "GitHub Actions: weekly Trivy rescan of running images. Read-only."
}

resource "google_project_iam_member" "ci_scanner" {
  for_each = toset([
    "roles/run.viewer",              # find which image each service runs
    "roles/artifactregistry.reader", # pull it for scanning
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ci_scanner.email}"
}

resource "google_service_account_iam_member" "ci_scanner_wif" {
  service_account_id = google_service_account.ci_scanner.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.wif_principal_prefix}:scan"
}
