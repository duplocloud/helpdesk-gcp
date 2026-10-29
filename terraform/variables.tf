# ── Project ───────────────────────────────────────────────────────────────────
variable "project_id" {
  description = "GCP project ID to deploy into"
  type        = string
}

variable "region" {
  description = "GCP region to deploy into (e.g. us-central1). The GKE cluster is regional."
  type        = string
}

variable "credentials_file" {
  description = "Path to a GCP service-account key JSON file. Leave empty to use Application Default Credentials (gcloud auth / metadata)."
  type        = string
  default     = ""
}

# ── Deployment ────────────────────────────────────────────────────────────────
variable "prefix" {
  description = "Name of this deployment, used in every resource name (<prefix>-vpc, gke-<prefix>, <prefix>-backend, ...). 1-17 characters so service account IDs fit GCP's 30-character limit"
  type        = string
  default     = "duplo-ai"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,15}[a-z0-9]$|^[a-z]$", var.prefix))
    error_message = "prefix must start with a lowercase letter, end with a letter or digit, contain only lowercase letters, digits and hyphens, and be 1-17 characters long."
  }
}

variable "environment" {
  description = "Environment name, applied as the environment label on every resource (e.g. production, staging, dev)"
  type        = string
  default     = "production"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,62}$", var.environment))
    error_message = "environment must be a lowercase GCP label value (letters, digits, '_' and '-', starting with a letter)."
  }
}

# ── GKE (Standard only; Autopilot is not supported) ───────────────────────────
variable "cluster_name" {
  description = "GKE cluster name. Empty: gke-<prefix>"
  type        = string
  default     = ""

  validation {
    condition     = var.cluster_name == "" || can(regex("^[a-z][a-z0-9-]{0,38}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must start with a lowercase letter, end with a letter or digit, contain only lowercase letters, digits and hyphens, and be at most 40 characters."
  }
}

variable "release_channel" {
  description = "GKE release channel: RAPID, REGULAR, STABLE, EXTENDED or UNSPECIFIED. Empty: GKE's default (REGULAR)"
  type        = string
  default     = ""

  validation {
    condition     = contains(["", "RAPID", "REGULAR", "STABLE", "EXTENDED", "UNSPECIFIED"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, STABLE, EXTENDED or UNSPECIFIED."
  }
}

variable "gke_enable_dns_endpoint" {
  description = "Allow IAM-authorized kubectl/Terraform access through the cluster's DNS-based control-plane endpoint (reachable from any network, independent of master_authorized_cidrs). Off by default: the public IP endpoint, limited to master_authorized_cidrs, is used instead"
  type        = bool
  default     = false
}

variable "gke_control_plane_logs_enabled" {
  description = "Send API server, scheduler and controller-manager logs to Cloud Logging (system and workload logs are always on)"
  type        = bool
  default     = true
}

variable "gke_maintenance_window" {
  description = "Recurring window in which GKE may auto-upgrade the cluster and nodes. Times are RFC 3339 (UTC); only the time of day and duration are used. Must leave at least 48 hours in any 32 days"
  type = object({
    start_time = string
    end_time   = string
    recurrence = string
  })
  default = {
    start_time = "2026-01-03T03:00:00Z"
    end_time   = "2026-01-03T11:00:00Z"
    recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
  }
}

variable "gke_deletion_protection" {
  description = "Protect the GKE cluster from deletion; set false and apply before terraform destroy"
  type        = bool
  default     = false
}

variable "cmek_key" {
  description = "Cloud KMS key (CMEK, projects/<p>/locations/<region>/keyRings/<r>/cryptoKeys/<k>) for Kubernetes Secrets in etcd. Must be in the cluster's region. Empty = Google-managed encryption"
  type        = string
  default     = ""
}

# ── Worker nodes ──────────────────────────────────────────────────────────────
variable "node_machine_type" {
  description = "Machine type for worker nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "node_min" {
  description = "Minimum TOTAL node count across all node pool zones combined (autoscaling; 0 allows scale-to-zero)"
  type        = number
  default     = 0

  validation {
    condition     = var.node_min >= 0
    error_message = "node_min must be 0 or more."
  }
}

variable "node_max" {
  description = "Maximum TOTAL node count across all node pool zones combined (autoscaling)"
  type        = number
  default     = 3

  validation {
    condition     = var.node_max >= 1 && var.node_max >= var.node_min
    error_message = "node_max must be at least 1 and at least node_min."
  }
}

variable "node_zones" {
  description = "Zones for the node pool (e.g. [\"us-central1-a\", \"us-central1-b\"]). Empty = every zone in the region"
  type        = list(string)
  default     = []
}

variable "node_disk_size" {
  description = "Boot disk size in GB for worker nodes"
  type        = number
  default     = 50
}

variable "node_disk_type" {
  description = "Boot disk type for worker nodes (pd-standard, pd-balanced, pd-ssd)"
  type        = string
  default     = "pd-balanced"
}

# ── Networking ────────────────────────────────────────────────────────────────
variable "subnet_cidr" {
  description = "Primary CIDR for the GKE node subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range CIDR for Pod IPs (VPC-native)"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "Secondary range CIDR for Service (ClusterIP) IPs (VPC-native)"
  type        = string
  default     = "10.8.0.0/20"
}

variable "proxy_only_subnet_cidr" {
  description = "CIDR for the regional proxy-only subnet used by Gateway API / regional Envoy-based load balancers. Must not overlap subnet_cidr, pods_cidr or services_cidr."
  type        = string
  default     = "10.16.0.0/23"
}

variable "psa_range_prefix_length" {
  description = "Prefix length of the auto-allocated internal range reserved for Private Service Access (VPC peering for Google managed services)"
  type        = number
  default     = 20
}

variable "master_authorized_cidrs" {
  description = "Restrict the control plane's public IP endpoint to these CIDRs (include where Terraform and kubectl run from). Empty: no authorized networks configured, so the endpoint accepts any IP (requests still need IAM)"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "nat_ip_allocation" {
  description = "Cloud NAT egress IPs: \"auto\" (allocated by Google, may change) or \"static\" (nat_static_ip_count reserved addresses, for third-party allowlists)"
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "static"], var.nat_ip_allocation)
    error_message = "nat_ip_allocation must be \"auto\" or \"static\"."
  }
}

variable "nat_static_ip_count" {
  description = "Number of static NAT IPs to reserve when nat_ip_allocation = \"static\""
  type        = number
  default     = 1

  validation {
    condition     = var.nat_static_ip_count >= 1
    error_message = "nat_static_ip_count must be at least 1."
  }
}

# ── DNS and certificate ───────────────────────────────────────────────────────
variable "helpdesk_dns" {
  description = "Primary DNS name for the helpdesk (e.g. helpdesk.example.com)"
  type        = string
}

variable "helpdesk_xterm_dns" {
  description = "DNS name for the helpdesk xterm service"
  type        = string
}

variable "dns_managed_zone" {
  description = "Cloud DNS managed zone NAME (not the domain) serving both hostnames; Terraform creates the A and certificate-validation records in it. Empty = DNS is hosted outside Cloud DNS: create the records from the dns_records output at your DNS provider"
  type        = string
  default     = ""
}

variable "dns_project_id" {
  description = "Project that owns dns_managed_zone, when the zone is in a different GCP project. Empty = project_id"
  type        = string
  default     = ""
}

# ── Helm chart ────────────────────────────────────────────────────────────────
variable "helm_chart_version" {
  description = "duplo-helpdesk Helm chart version (oci://quay.io/duplocloud/helpdesk)"
  type        = string
  default     = "0.2.24"
}

variable "helm_release_name" {
  description = "Helm release name; also the prefix of the chart's Kubernetes objects (<name>-backend, ...)"
  type        = string
  default     = "duplo-ai-helpdesk"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,40}[a-z0-9]$", var.helm_release_name))
    error_message = "helm_release_name must start with a lowercase letter, end with a letter or digit, contain only lowercase letters, digits and hyphens, and be at most 42 characters."
  }
}

variable "helm_namespace" {
  description = "Kubernetes namespace for the Helm release"
  type        = string
  default     = "duplo-helpdesk"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.helm_namespace))
    error_message = "helm_namespace must be a valid Kubernetes namespace: lowercase letters, digits and hyphens, at most 63 characters, starting and ending with a letter or digit."
  }
}

variable "helm_values_override_file" {
  description = "Required. Path to the customer's Helm values file (app secrets, login providers, Slack, ...), applied on top of modules/helpdesk/values/default.yml; its keys win (lists are replaced, not merged). Values Terraform derives from the infrastructure cannot be overridden. Start from values-override.example.yml"
  type        = string

  validation {
    condition     = can(yamldecode(file(var.helm_values_override_file)))
    error_message = "helm_values_override_file must point to a readable YAML file (copy values-override.example.yml)."
  }

  validation {
    condition     = try(yamldecode(file(var.helm_values_override_file)).mongodb.auth.rootPassword, "") != ""
    error_message = "The override file must set mongodb.auth.rootPassword: the chart builds the backend's connection string from it."
  }
}

variable "backend_impersonate_service_accounts" {
  description = "Service account emails in other projects the helpdesk backend may impersonate (roles/iam.serviceAccountTokenCreator); it can already impersonate any service account in this project"
  type        = list(string)
  default     = []
}

variable "helpdesk_analytics_collector_enabled" {
  description = "Run the analytics collector, which reports usage from the helpdesk database to the DuploCloud control plane for reporting and billing"
  type        = bool
  default     = true
}

variable "helpdesk_analytics_collector_app_instance" {
  description = "Identifier this deployment reports under; unique per helpdesk deployment in a cloud environment. Empty = defaults to prefix (var.prefix)"
  type        = string
  default     = ""
}

# ── Labels ────────────────────────────────────────────────────────────────────
variable "common_labels" {
  description = "Extra labels for every resource (e.g. environment, team, cost_center). Merged over the defaults app, deployment (= prefix) and managed_by"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([for k, v in var.common_labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "common_labels keys must start with a lowercase letter; keys and values may only contain lowercase letters, digits, '_' and '-' (max 63 characters)."
  }
}
