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

# --- Cloud SQL -----------------------------------------------------------------

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-f1-micro"
}

variable "db_availability_type" {
  description = "ZONAL for dev, REGIONAL (HA) for prod."
  type        = string
  default     = "ZONAL"
}

variable "db_name" {
  description = "Application database name."
  type        = string
  default     = "app"
}

variable "db_user" {
  description = "Application database user."
  type        = string
  default     = "app"
}

variable "db_deletion_protection" {
  description = "Protect the DB instance from deletion. false in dev so destroy works."
  type        = bool
  default     = false
}

# --- Cloud Run / Load balancer ---------------------------------------------------

variable "min_instances" {
  description = "0 = scale to zero (no idle cost, cold starts). 1+ for prod."
  type        = number
  default     = 0
}

variable "max_instances" {
  type    = number
  default = 3
}

variable "enable_https" {
  description = "Managed certificate on <ip>.nip.io + :443 listener."
  type        = bool
  default     = false
}

variable "redirect_http_to_https" {
  description = "Redirect :80 to HTTPS. Turn on only after the certificate is ACTIVE."
  type        = bool
  default     = false
}
