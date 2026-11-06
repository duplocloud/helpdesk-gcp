variable "mode" {
  description = "filestore (new instances through the Filestore CSI driver), existing (an existing Filestore share) or incluster (the chart's NFS server)"
  type        = string

  validation {
    condition     = contains(["filestore", "existing", "incluster"], var.mode)
    error_message = "mode must be \"filestore\", \"existing\" or \"incluster\"."
  }
}

variable "deployment_name" {
  description = "Deployment name, put on the Filestore instance as the duplocloud-deployment label (filestore mode)"
  type        = string
  default     = ""
  nullable    = false
}

variable "project_id" {
  description = "Project the Filestore instance is created in (filestore mode; used in the cleanup command)"
  type        = string
  default     = ""
  nullable    = false
}

variable "storage_class_name" {
  description = "Name of the RWX storage class Helpdesk mounts"
  type        = string
  default     = "ai-studio-filestore"
  nullable    = false
}

variable "filestore_size" {
  description = "Size of the Filestore instance (filestore mode; Basic HDD), at least 100Gi, e.g. 100Gi or 1Ti"
  type        = string
  default     = "100Gi"
  nullable    = false

  validation {
    condition     = can(regex("^[1-9][0-9]*(Gi|Ti)$", var.filestore_size))
    error_message = "filestore_size must be a size in Gi or Ti, e.g. 100Gi or 1Ti."
  }
}

variable "network_name" {
  description = "VPC network name the new Filestore instances attach to (filestore mode)"
  type        = string
  default     = ""
  nullable    = false
}

variable "filestore_ip" {
  description = "NFS server IP of the existing Filestore instance (existing mode)"
  type        = string
  default     = ""
  nullable    = false
}

variable "filestore_share" {
  description = "Share name of the existing Filestore instance (existing mode)"
  type        = string
  default     = ""
  nullable    = false
}

variable "nfs_provisioner_chart_version" {
  description = "nfs-subdir-external-provisioner chart version (existing mode)"
  type        = string
  default     = "4.0.18"
  nullable    = false
}

variable "nfs_provisioner_namespace" {
  description = "Namespace of the NFS provisioner (existing mode)"
  type        = string
  default     = "nfs-provisioner"
  nullable    = false
}

variable "nfs_server_disk_size" {
  description = "Persistent Disk size of the in-cluster NFS server (incluster mode)"
  type        = string
  default     = "50Gi"
  nullable    = false
}
