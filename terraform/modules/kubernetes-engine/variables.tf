variable "project_number" {
  description = "GCP project number (GKE service agent identity)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name_prefix" {
  description = "Deployment name in the node service account and node pool names (<prefix>-gke-node, np-<prefix>-default)"
  type        = string
}

variable "release_channel" {
  description = "Release channel (RAPID, REGULAR, STABLE, EXTENDED, UNSPECIFIED); empty uses GKE's default"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment label on the cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "GCP region for the regional cluster"
  type        = string
}

variable "workload_pool" {
  description = "Workload Identity pool (e.g. PROJECT_ID.svc.id.goog)"
  type        = string
}

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the nodes"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for Pod IPs"
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for Service IPs"
  type        = string
}

variable "master_authorized" {
  description = "CIDRs allowed to reach the control plane's public IP endpoint; empty leaves authorized networks unset"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
}

variable "node_machine_type" {
  description = "Machine type for worker nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "node_min" {
  description = "Minimum TOTAL node count across all node pool zones combined (autoscaling; 0 allows scale-to-zero)"
  type        = number
  default     = 0
}

variable "node_max" {
  description = "Maximum TOTAL node count across all node pool zones combined (autoscaling)"
  type        = number
  default     = 3
}

variable "node_zones" {
  description = "Zones for the node pool (e.g. [\"us-central1-a\", \"us-central1-b\"]). Empty = every zone in the region"
  type        = list(string)
  default     = []
}

variable "node_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "node_disk_type" {
  description = "Boot disk type (pd-standard, pd-balanced, pd-ssd)"
  type        = string
  default     = "pd-balanced"
}

variable "enable_dns_endpoint" {
  description = "Allow IAM-authorized access to the control plane through its DNS-based endpoint"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent the cluster from being deleted (set false and apply before terraform destroy)"
  type        = bool
  default     = true
}

variable "cmek_key" {
  description = "Cloud KMS key (projects/<p>/locations/<region>/keyRings/<r>/cryptoKeys/<k>) for Secrets encryption and backups. Empty = Google-managed encryption"
  type        = string
  default     = ""
}

variable "maintenance_window" {
  description = "Recurring maintenance window for auto-upgrades (RFC 3339 times; only the time of day and duration matter)"
  type = object({
    start_time = string
    end_time   = string
    recurrence = string
  })
}

variable "labels" {
  description = "Common labels, set explicitly where provider default_labels don't apply (node VMs and disks)"
  type        = map(string)
  default     = {}
}

variable "control_plane_logs_enabled" {
  description = "API server, scheduler and controller-manager logs to Cloud Logging"
  type        = bool
  default     = true
}
