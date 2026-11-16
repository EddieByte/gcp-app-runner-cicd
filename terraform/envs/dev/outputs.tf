output "runtime_sa_email" {
  value = module.iam.runtime_sa_email
}

output "deployer_sa_email" {
  value = module.iam.deployer_sa_email
}

output "image_repository_url" {
  description = "Push images here: <url>/php-app:<tag>"
  value       = module.artifact_registry.repository_url
}

output "db_instance_name" {
  value = module.cloudsql.instance_name
}

output "db_connection_name" {
  description = "Used by Cloud Run's Cloud SQL connection: /cloudsql/<connection_name>"
  value       = module.cloudsql.connection_name
}

output "db_password_secret_id" {
  value = module.cloudsql.password_secret_id
}

# Copy into GitHub: Settings -> Environments -> dev -> Environment variables
output "github_environment_vars" {
  value = {
    DEPLOYER_SA       = module.iam.deployer_sa_email
    CLOUD_RUN_SERVICE = module.cloudrun.service_name
    STATIC_BUCKET     = module.static_bucket.bucket_name
    APP_URL           = coalesce(module.loadbalancer.https_url, module.loadbalancer.http_url)
  }
}

output "app_url" {
  description = "Open this in a browser (LB may need ~5-10 min after first apply)."
  value       = module.loadbalancer.http_url
}

output "https_url" {
  value = module.loadbalancer.https_url
}

output "lb_ip_address" {
  value = module.loadbalancer.ip_address
}

output "cloud_run_service" {
  value = module.cloudrun.service_name
}

output "static_bucket" {
  value = module.static_bucket.bucket_name
}

output "certificate_name" {
  value = module.loadbalancer.certificate_name
}
