output "runtime_sa_email" {
  description = "Email of the Cloud Run runtime service account."
  value       = google_service_account.runtime.email
}

output "runtime_sa_name" {
  description = "Fully qualified name, used for SA-level IAM bindings."
  value       = google_service_account.runtime.name
}

output "deployer_sa_email" {
  description = "Email of the CI/CD deployer service account."
  value       = google_service_account.deployer.email
}

output "deployer_sa_name" {
  description = "Fully qualified name, used by the workload-identity module."
  value       = google_service_account.deployer.name
}
