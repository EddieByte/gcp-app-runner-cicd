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
