output "service_name" {
  value = google_cloud_run_v2_service.this.name
}

output "service_uri" {
  description = "*.run.app URL (blocked for internet traffic when ingress is LB-only)."
  value       = google_cloud_run_v2_service.this.uri
}
