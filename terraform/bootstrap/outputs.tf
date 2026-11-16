output "tfstate_bucket" {
  description = "Bucket name to use in every other root's backend \"gcs\" block."
  value       = google_storage_bucket.tfstate.name
}

output "enabled_apis" {
  value = sort([for s in google_project_service.apis : s.service])
}

# Copy these into GitHub: Settings -> Secrets and variables -> Actions -> Variables
output "github_vars" {
  description = "Repository-level GitHub Actions variables."
  value = {
    WIF_PROVIDER = google_iam_workload_identity_pool_provider.github.name
    BUILDER_SA   = google_service_account.ci_builder.email
    SCANNER_SA   = google_service_account.ci_scanner.email
  }
}

# Consumed by envs/* via terraform_remote_state to bind per-env deployers.
output "wif_pool_name" {
  value = google_iam_workload_identity_pool.github.name
}

output "github_repository" {
  value = var.github_repository
}
