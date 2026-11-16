variable "project_id" {
  description = "Project to create the service accounts in."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for SA IDs, e.g. php-app-dev. SA IDs must be 6-30 chars."
  type        = string

  validation {
    condition     = length(var.name_prefix) <= 23
    error_message = "name_prefix must be <= 23 chars so '<prefix>-deploy' fits the 30-char SA ID limit."
  }
}

variable "wif_pool_name" {
  description = "Full Workload Identity Pool name (projects/<num>/locations/global/workloadIdentityPools/<id>)."
  type        = string
}

variable "github_repository" {
  description = "GitHub repo (owner/name) allowed to deploy."
  type        = string
}

variable "release_channel" {
  description = "WIF channel this deployer accepts: dev (dev-vX.Y.Z tags) or prod (vX.Y.Z tags)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.release_channel)
    error_message = "release_channel must be dev or prod."
  }
}
