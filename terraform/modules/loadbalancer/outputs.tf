output "ip_address" {
  description = "Stable public IP of the application."
  value       = google_compute_global_address.this.address
}

output "ip_name" {
  description = "Name of the reserved address (used by scripts/get-service-ip.sh)."
  value       = google_compute_global_address.this.name
}

output "http_url" {
  value = "http://${google_compute_global_address.this.address}"
}

output "https_url" {
  value = var.enable_https ? "https://${local.domain}" : null
}
