variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "duplo-ai-helpdesk"
}

variable "project_id" {
  description = "GCP project ID (config.googleCloudProject — Vertex AI calls)"
  type        = string
}

variable "region" {
  description = "GCP region (config.infraRegion)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the release"
  type        = string
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "0.2.24"
}

variable "helpdesk_dns" {
  description = "Helpdesk DNS hostname (e.g. helpdesk.example.com)"
  type        = string
}

variable "helpdesk_xterm_dns" {
  description = "Helpdesk xterm DNS hostname"
  type        = string
}

variable "gateway_ip_name" {
  description = "Name of the reserved global IP for the external Gateway"
  type        = string
}

variable "certificate_map_name" {
  description = "Certificate Manager certificate map for the external Gateway"
  type        = string
}

variable "ssl_policy_name" {
  description = "SSL policy for the external Gateway"
  type        = string
}

variable "values_override" {
  description = "Customer's Helm values YAML, applied after values/default.yml (its keys win) and before the values Terraform sets"
  type        = string
  sensitive   = true
}

variable "helpdesk_analytics_collector_enabled" {
  description = "Enable the analytics collector deployment"
  type        = bool
}

variable "helpdesk_analytics_collector_app_instance" {
  description = "Identifier the collector reports under (collector.product.instance); required when the collector is enabled"
  type        = string
}

variable "workload_pool" {
  description = "Workload Identity pool (<project>.svc.id.goog)"
  type        = string
}

variable "name_prefix" {
  description = "Deployment name in the Google service account IDs (<prefix>-backend, <prefix>-agent, <prefix>-collector)"
  type        = string
}

variable "backend_impersonate_service_accounts" {
  description = "Service account emails (in any project) the helpdesk backend may impersonate (roles/iam.serviceAccountTokenCreator)"
  type        = list(string)
  default     = []
}

