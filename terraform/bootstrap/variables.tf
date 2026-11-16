variable "project_id" {
  description = "GCP project ID that hosts the whole stack."
  type        = string
}

variable "region" {
  description = "Default region for regional resources (state bucket location)."
  type        = string
  default     = "europe-west1"
}
