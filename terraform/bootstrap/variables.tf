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
