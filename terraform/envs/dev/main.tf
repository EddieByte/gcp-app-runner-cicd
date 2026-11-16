# -----------------------------------------------------------------------------
# dev environment: composes the reusable modules.
# Modules are added in dependency order as the build progresses:
#   iam -> artifact-registry -> cloudsql -> storage -> cloudrun -> loadbalancer
#   -> workload-identity
# -----------------------------------------------------------------------------

locals {
  # e.g. "php-app-dev": one consistent prefix for every resource name.
  name_prefix = "${var.app_name}-${var.environment}"
}

module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  name_prefix = local.name_prefix
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = var.artifact_repository_id
}
