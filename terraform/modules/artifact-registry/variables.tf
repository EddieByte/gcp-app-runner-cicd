variable "project_id" {
  type = string
}

variable "region" {
  description = "Repository location; keep it in the same region as Cloud Run."
  type        = string
}

variable "repository_id" {
  description = "Repository name, e.g. php-app."
  type        = string
}

variable "keep_recent_count" {
  description = "Number of most recent images always kept (rollback targets)."
  type        = number
  default     = 10
}

variable "retention_days" {
  description = "Images older than this (and not in the recent set) are deleted."
  type        = number
  default     = 30
}
