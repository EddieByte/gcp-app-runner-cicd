# -----------------------------------------------------------------------------
# dev environment: versions + remote state
# State lives in the bucket created by terraform/bootstrap, under env/dev.
# The GCS backend provides state locking natively (no DynamoDB-style table).
# Docs: https://developer.hashicorp.com/terraform/language/backend/gcs
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "php-cloudrun-platform-tfstate" # backend blocks can't use variables
    prefix = "env/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
