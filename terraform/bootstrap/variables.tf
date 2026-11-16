variable "project_id" {
  description = "GCP project ID that hosts the whole stack."
  type        = string
}

variable "region" {
  description = "Default region for regional resources (state bucket location)."
  type        = string
  default     = "europe-west1"
}

variable "enable_state_versioning" {
  description = "Keep previous versions of state files for recovery. Recommended true outside throwaway environments."
  type        = bool
  default     = false
}

variable "github_repository" {
  description = "GitHub repo allowed to authenticate, as owner/name."
  type        = string
  default     = "EddieByte/gcp-app-runner-cicd"
}

variable "wif_pool_id" {
  description = "Workload Identity Pool ID. Deleted pool IDs are reserved for 30 days, so change this if you recreate it."
  type        = string
  default     = "github"
}

variable "scan_branch" {
  description = "Branch whose scheduled runs may use the read-only scanner identity."
  type        = string
  default     = "main"
}
