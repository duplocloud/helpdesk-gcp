variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Naming prefix (the cluster name, as in the AWS repo): <cluster_name>-cert, -certmap, -dnsauth-<host>"
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

variable "create_dns_records" {
  description = "Write the certificate validation records into dns_zone_name (managed mode); false emits them for an external DNS provider"
  type        = bool
  default     = true
  nullable    = false
}

variable "dns_zone_name" {
  description = "Cloud DNS managed zone NAME (not the domain) serving both hostnames"
  type        = string
  default     = ""
  nullable    = false
}

variable "dns_project_id" {
  description = "Project that owns dns_zone_name; empty means the deployment project"
  type        = string
  default     = ""
  nullable    = false
}
