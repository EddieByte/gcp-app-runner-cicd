variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "service_name" {
  type = string
}

variable "app_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "image" {
  description = "Initial image only. Later images are deployed by CI and ignored by Terraform."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "runtime_sa_email" {
  type = string
}

variable "cloudsql_connection_name" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password_secret_id" {
  type = string
}

variable "ingress" {
  description = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER (LB only) or INGRESS_TRAFFIC_ALL."
  type        = string
  default     = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 3
}

variable "concurrency" {
  description = "Requests per instance. Kept modest: each PHP-FPM worker holds one DB connection."
  type        = number
  default     = 20
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "labels" {
  type    = map(string)
  default = {}
}
