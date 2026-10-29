variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name_prefix" {
  description = "Deployment name in the IP, DNS authorization, certificate, certificate map and SSL policy names (<prefix>-gateway, cert-<prefix>-helpdesk, ...)"
  type        = string
}

variable "helpdesk_dns" {
  description = "Primary DNS name for the helpdesk"
  type        = string
}

variable "helpdesk_xterm_dns" {
  description = "DNS name for the helpdesk xterm service"
  type        = string
}

variable "dns_managed_zone" {
  description = "Cloud DNS managed zone name (not the domain) serving the helpdesk hostnames. Empty = DNS hosted outside Cloud DNS; create the dns_records output yourself"
  type        = string
  default     = ""
}

variable "dns_project_id" {
  description = "Project that owns dns_managed_zone, when it isn't the deployment project. Empty = project_id"
  type        = string
  default     = ""
}
