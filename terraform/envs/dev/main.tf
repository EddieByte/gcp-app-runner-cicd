# -----------------------------------------------------------------------------
# dev environment: composes the reusable modules.
# Modules are added in dependency order as the build progresses:
#   iam -> artifact-registry -> cloudsql -> storage -> cloudrun -> loadbalancer
#   -> workload-identity
# -----------------------------------------------------------------------------

locals {
  # e.g. "php-app-dev": one consistent prefix for every resource name.
  name_prefix = "${var.app_name}-${var.environment}"

  # Applied to every resource that supports labels (cost reporting, filtering).
  labels = {
    app         = var.app_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Read shared outputs (WIF pool, repo) from the bootstrap state instead of
# copy-pasting them: one source of truth.
# Docs: https://developer.hashicorp.com/terraform/language/state/remote-state-data
data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = "${var.project_id}-tfstate"
    prefix = "bootstrap"
  }
}

module "iam" {
  source = "../../modules/iam"

  project_id        = var.project_id
  name_prefix       = local.name_prefix
  wif_pool_name     = data.terraform_remote_state.bootstrap.outputs.wif_pool_name
  github_repository = data.terraform_remote_state.bootstrap.outputs.github_repository
  release_channel   = var.environment
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = var.artifact_repository_id

  # The deployer only deploys images (it never pushes), but gcloud run deploy
  # checks it can read the image it's deploying.
  reader_members = ["serviceAccount:${module.iam.deployer_sa_email}"]
}

module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id       = var.project_id
  region           = var.region
  name_prefix      = local.name_prefix
  runtime_sa_email = module.iam.runtime_sa_email

  tier                = var.db_tier
  availability_type   = var.db_availability_type
  database_name       = var.db_name
  database_user       = var.db_user
  deletion_protection = var.db_deletion_protection
  labels              = local.labels
}

module "static_bucket" {
  source = "../../modules/storage"

  project_id    = var.project_id
  region        = var.region
  bucket_name   = "${var.project_id}-${var.environment}-static"
  force_destroy = true # dev only: lets `terraform destroy` remove synced files
  labels        = local.labels

  # This environment's deployer syncs app/public/static on every release.
  writer_members = ["serviceAccount:${module.iam.deployer_sa_email}"]
}

module "cloudrun" {
  source = "../../modules/cloudrun"

  project_id   = var.project_id
  region       = var.region
  service_name = local.name_prefix
  app_name     = var.app_name
  environment  = var.environment
  labels       = local.labels

  runtime_sa_email         = module.iam.runtime_sa_email
  cloudsql_connection_name = module.cloudsql.connection_name
  db_name                  = module.cloudsql.database_name
  db_user                  = module.cloudsql.database_user
  db_password_secret_id    = module.cloudsql.password_secret_id

  min_instances = var.min_instances
  max_instances = var.max_instances

  # The runtime SA must be able to read the secret before the first revision
  # starts, or the deploy fails.
  depends_on = [module.cloudsql]
}

module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_id             = var.project_id
  region                 = var.region
  name_prefix            = local.name_prefix
  cloud_run_service_name = module.cloudrun.service_name
  static_bucket_name     = module.static_bucket.bucket_name
  enable_https           = var.enable_https
  redirect_http_to_https = var.redirect_http_to_https
  labels                 = local.labels
}
