# -----------------------------------------------------------------------------
# Module: iam
#
# Two dedicated service accounts instead of the default compute SA:
#   - runtime  : identity the Cloud Run container runs as (like an ECS task role)
#   - deployer : identity GitHub Actions impersonates to deploy (via WIF, no keys)
#
# Why not the default SA? Our org enforces
# iam.automaticIamGrantsForDefaultServiceAccounts, so default SAs get no roles,
# and least privilege is better practice anyway.
# Docs: https://cloud.google.com/iam/docs/service-account-overview
#       https://cloud.google.com/run/docs/securing/service-identity
# -----------------------------------------------------------------------------

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-run"
  display_name = "Cloud Run runtime (${var.name_prefix})"
  description  = "Identity of the running PHP container. Least privilege."
}

resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-deploy"
  display_name = "CI/CD deployer (${var.name_prefix})"
  description  = "Impersonated by GitHub Actions through Workload Identity Federation."
}

# Project-level roles for the runtime SA.
# Resource-scoped grants (the DB secret, the static bucket) live in the modules
# that own those resources, so access is as narrow as possible.
resource "google_project_iam_member" "runtime" {
  for_each = toset([
    "roles/cloudsql.client",         # connect through the Cloud SQL connector
    "roles/logging.logWriter",       # write application logs
    "roles/monitoring.metricWriter", # write custom metrics
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# Project-level roles for the deployer SA.
resource "google_project_iam_member" "deployer" {
  for_each = toset([
    "roles/run.admin",               # create/update Cloud Run revisions
    "roles/artifactregistry.writer", # push images
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# The deployer must be allowed to "act as" the runtime SA when it deploys a
# revision that runs as that SA. Granted on the SA itself, not project-wide.
# Docs: https://cloud.google.com/run/docs/reference/iam/roles#additional-configuration
resource "google_service_account_iam_member" "deployer_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}
