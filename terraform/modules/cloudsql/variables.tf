variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name_prefix" {
  description = "Naming prefix, e.g. php-app-dev."
  type        = string
}

variable "runtime_sa_email" {
  description = "Service account allowed to read the DB password secret (Cloud Run runtime SA)."
  type        = string
}

variable "database_version" {
  description = "Cloud SQL engine version."
  type        = string
  default     = "MYSQL_8_0"
}

variable "tier" {
  description = "Machine tier. db-f1-micro is the cheapest shared-core tier (dev only)."
  type        = string
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "ZONAL (single zone, cheaper) or REGIONAL (high availability)."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be ZONAL or REGIONAL."
  }
}

variable "disk_size_gb" {
  type    = number
  default = 10 # minimum
}

variable "disk_autoresize_limit_gb" {
  description = "Upper bound for automatic disk growth (0 = unlimited)."
  type        = number
  default     = 20
}

variable "backup_retention_count" {
  description = "Number of daily backups to keep."
  type        = number
  default     = 7
}

variable "database_name" {
  description = "Application database name."
  type        = string
  default     = "app"
}

variable "database_user" {
  description = "Application database user."
  type        = string
  default     = "app"
}

variable "deletion_protection" {
  description = "Block deletion of the instance. false for dev so `terraform destroy` works; true for prod."
  type        = bool
  default     = false
}

variable "labels" {
  type    = map(string)
  default = {}
}
