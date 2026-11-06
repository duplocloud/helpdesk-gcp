variable "project_id" {
  description = "GCP project ID (config.googleCloudProject, Vertex AI calls)"
  type        = string
}

variable "region" {
  description = "Region (config.infraRegion)"
  type        = string
}

variable "cluster_name" {
  description = "Naming prefix (the cluster name, as in the AWS repo): <cluster_name>-gateway, -ssl-policy, -backend, ..."
  type        = string
}

variable "deployment_name" {
  description = "Deployment name (analytics collector instance)"
  type        = string
}

variable "workload_pool" {
  description = "Workload Identity pool (<project>.svc.id.goog)"
  type        = string
}

variable "helpdesk_dns" {
  description = "Helpdesk hostname"
  type        = string
}

variable "helpdesk_xterm_dns" {
  description = "Helpdesk xterm hostname"
  type        = string
}

variable "certificate_map_name" {
  description = "Certificate map the Gateway serves"
  type        = string
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "duplo-ai-helpdesk"
  nullable    = false
}

variable "namespace" {
  description = "Kubernetes namespace for the Helpdesk release (created if missing); Workload Identity bindings follow it"
  type        = string
  default     = "helpdesk"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", var.namespace))
    error_message = "namespace must be a Kubernetes name: lowercase letters, digits and '-', at most 63 characters."
  }
}

variable "chart_version" {
  # The build of helpdesk-helm feature/filestore-backend (PR #100): the first chart with filestore.*.
  # Move to the release that ships it once the PR merges.
  description = "Helpdesk chart version"
  type        = string
  default     = "0.2.24-feature-filestore-backend-09fe37e"
  nullable    = false
}

variable "storage" {
  description = "Shared storage from modules/storage: mode (filestore, existing or incluster), the StorageClass name, and the mode's settings"
  type = object({
    mode                 = string
    class_name           = optional(string, "")
    filestore_size       = optional(string, "100Gi")
    nfs_server_disk_size = optional(string, "50Gi")
  })

  validation {
    condition     = contains(["filestore", "existing", "incluster"], var.storage.mode)
    error_message = "storage.mode must be filestore, existing or incluster."
  }
}

variable "bucket_name" {
  description = "App data bucket the backend may use; empty grants nothing"
  type        = string
  default     = ""
  nullable    = false
}

variable "userdata_bucket_name" {
  description = "User data bucket the backend may use; empty grants nothing"
  type        = string
  default     = ""
  nullable    = false
}

variable "dns_zone_name" {
  description = "Cloud DNS zone for the A records (managed DNS mode); empty skips them"
  type        = string
  default     = ""
  nullable    = false
}

variable "dns_zone_project" {
  description = "Project owning dns_zone_name; empty means project_id"
  type        = string
  default     = ""
  nullable    = false
}

variable "local_admin_email" {
  description = "Email of the local admin (also the Helpdesk super user), who signs in with secrets.local_admin_password"
  type        = string
  default     = ""
  nullable    = false
}

variable "backend_image_tag" {
  description = "Backend image tag; empty uses the chart default"
  type        = string
  default     = ""
  nullable    = false
}

variable "frontend_image_tag" {
  description = "Frontend image tag; empty uses the chart default"
  type        = string
  default     = ""
  nullable    = false
}

variable "agent_image_tag" {
  description = "duplo-agent image tag; empty uses the chart default"
  type        = string
  default     = ""
  nullable    = false
}

variable "helpdesk_analytics_collector_enabled" {
  description = "Run the analytics collector"
  type        = bool
  default     = true
  nullable    = false
}

variable "helpdesk_mcp_enabled" {
  description = "Run the Helpdesk MCP server"
  type        = bool
  default     = true
  nullable    = false
}

variable "slack_backend_enabled" {
  description = "Run the Slack backend"
  type        = bool
  default     = false
  nullable    = false
}

variable "slack_backend_image_tag" {
  description = "Slack backend image tag"
  type        = string
  default     = ""
  nullable    = false
}

variable "slack_helpdesk_default_agent" {
  description = "Default agent for Slack"
  type        = string
  default     = ""
  nullable    = false
}

variable "slack_helpdesk_default_workspace" {
  description = "Default workspace for Slack"
  type        = string
  default     = ""
  nullable    = false
}

variable "slack_app_portals" {
  description = "Slack app portals (DUPLO_SLACK_APP_PORTALS)"
  type        = string
  default     = ""
  nullable    = false
}

variable "backend_impersonate_service_accounts" {
  description = "Service accounts (any project) the backend may impersonate"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "secrets" {
  description = "Secret values by key (licensing_token, local_admin_password, slack_app_token, slack_bot_token)"
  type        = map(string)
  default     = {}
  sensitive   = true
  nullable    = false
}

variable "jwt_shared_secret" {
  description = "Generated JWT shared secret"
  type        = string
  sensitive   = true
}

variable "mongodb_root_password" {
  description = "Generated MongoDB root password"
  type        = string
  sensitive   = true
}
