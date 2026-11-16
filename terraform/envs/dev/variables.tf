# Environment-specific values come from terraform.tfvars (git-ignored).
# See terraform.tfvars.example for the expected shape.

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for Cloud Run, Cloud SQL, Artifact Registry and buckets."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Environment name; used in resource names and labels."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "app_name" {
  description = "Short application name used as a naming prefix."
  type        = string
  default     = "php-app"
}

variable "artifact_repository_id" {
  description = "Artifact Registry repository name."
  type        = string
  default     = "php-app"
}
