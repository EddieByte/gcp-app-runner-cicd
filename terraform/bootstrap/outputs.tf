output "tfstate_bucket" {
  description = "Bucket name to use in every other root's backend \"gcs\" block."
  value       = google_storage_bucket.tfstate.name
}

output "enabled_apis" {
  value = sort([for s in google_project_service.apis : s.service])
}
