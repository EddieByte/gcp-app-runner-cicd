# -----------------------------------------------------------------------------
# Bootstrap: Terraform + provider versions
# Pin versions so every run (laptop, Cloud Shell, CI) behaves the same.
# Provider docs: https://registry.terraform.io/providers/hashicorp/google/latest/docs
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0" # check the registry for the latest major and pin it
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
