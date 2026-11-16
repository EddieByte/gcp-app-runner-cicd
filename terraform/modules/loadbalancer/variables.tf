variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "cloud_run_service_name" {
  type = string
}

variable "static_bucket_name" {
  type = string
}

variable "enable_cdn" {
  description = "Cache static files at Google's edge (small extra cost)."
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Add a Google-managed certificate and :443 listener (one extra forwarding rule)."
  type        = bool
  default     = false
}

variable "domain" {
  description = "Domain for the certificate. Empty = <ip>.nip.io."
  type        = string
  default     = ""
}

variable "security_policy" {
  description = "Optional Cloud Armor policy self-link."
  type        = string
  default     = null
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "redirect_http_to_https" {
  description = "301-redirect port 80 to HTTPS. Enable only after the managed certificate is ACTIVE."
  type        = bool
  default     = false
}
