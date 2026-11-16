variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "bucket_name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "writer_members" {
  description = "IAM members allowed to upload/delete objects, e.g. serviceAccount:deployer@..."
  type        = list(string)
  default     = []
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket. true for dev only."
  type        = bool
  default     = false
}

variable "labels" {
  type    = map(string)
  default = {}
}
