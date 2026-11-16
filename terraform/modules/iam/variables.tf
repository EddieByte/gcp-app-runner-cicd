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
