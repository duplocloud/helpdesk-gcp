variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region of the regional cluster"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "subnet_id" {
  description = "Node subnet ID"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range of the node subnet for Pod IPs (created by the vpc module or picked from the adopted subnet)"
  type        = string
  default     = null
}

variable "services_range_name" {
  description = "Secondary range of the node subnet for Service IPs (created by the vpc module or picked from the adopted subnet)"
  type        = string
  default     = null
}

variable "release_channel" {
  description = "Release channel: RAPID, REGULAR, STABLE or EXTENDED"
  type        = string
  default     = "REGULAR"
  nullable    = false
}

variable "node_machine_type" {
  description = "Machine type of the worker nodes"
  type        = string
  default     = "e2-standard-4"
  nullable    = false
}

variable "node_min" {
  description = "Minimum total node count across zones"
  type        = number
  default     = 1
  nullable    = false
}

variable "node_max" {
  description = "Maximum total node count across zones"
  type        = number
  default     = 3
  nullable    = false
}

variable "node_zones" {
  description = "Zones of the region for the node pool; none selected uses every zone in the region"
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for z in var.node_zones : startswith(z, "${var.region}-")])
    error_message = "node_zones must be zones of the cluster's region (e.g. us-central1-a for us-central1)."
  }
}

variable "node_disk_size" {
  description = "Node boot disk size in GB"
  type        = number
  default     = 50
  nullable    = false
}

variable "node_disk_type" {
  description = "Node boot disk type: pd-standard, pd-balanced or pd-ssd"
  type        = string
  default     = "pd-balanced"
  nullable    = false
}

variable "master_authorized_cidrs" {
  description = "CIDRs allowed to reach the control plane's public endpoint; empty leaves it open (IAM still applies)"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "enable_dns_endpoint" {
  description = "Also allow IAM-authorized access through the DNS-based control-plane endpoint; when on, OpenTofu connects through it instead of the public IP endpoint"
  type        = bool
  default     = false
  nullable    = false
}

variable "deletion_protection" {
  description = "Prevent the cluster from being deleted"
  type        = bool
  default     = false
  nullable    = false
}

variable "cmek_key" {
  description = "Cloud KMS key for Secrets encryption in etcd; empty uses Google-managed encryption"
  type        = string
  default     = ""
  nullable    = false
}

variable "control_plane_logs_enabled" {
  description = "Send API server, scheduler and controller-manager logs to Cloud Logging"
  type        = bool
  default     = true
  nullable    = false
}

variable "node_labels" {
  description = "Labels for the node VMs; provider default_labels don't reach a node pool's node_config.resource_labels"
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "additional_admin_members" {
  description = "Extra IAM members granted roles/container.admin on the project, e.g. user:ops@example.com"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "filestore_csi_enabled" {
  description = "Enable the GKE Filestore CSI driver, which the \"New Filestore\" storage option uses"
  type        = bool
  default     = true
  nullable    = false
}
