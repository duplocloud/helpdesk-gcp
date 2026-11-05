variable "project_id" {
  description = "GCP project ID (the deployment's account ID)"
  type        = string
}

variable "deployment_name" {
  description = "Deployment name, used in the bucket names"
  type        = string
}

variable "region" {
  description = "Bucket location"
  type        = string
}

variable "lifecycle_enabled" {
  description = "Delete objects after lifecycle_expiration_days"
  type        = bool
  default     = false
  nullable    = false
}

variable "lifecycle_expiration_days" {
  description = "Object age in days before deletion when lifecycle_enabled is on"
  type        = number
  default     = 90
  nullable    = false
}

variable "labels" {
  description = "Labels for the buckets"
  type        = map(string)
  default     = {}
  nullable    = false
}
