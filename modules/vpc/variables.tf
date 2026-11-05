variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Naming prefix (the cluster name, as in the AWS repo): <cluster_name>-vpc, -private, -router, ..."
  type        = string
}

variable "region" {
  description = "Region for the subnet, router and NAT"
  type        = string
}

variable "subnet_cidr" {
  description = "Primary CIDR of the node subnet"
  type        = string
  default     = "10.0.0.0/20"
  nullable    = false
}

variable "pods_cidr" {
  description = "Secondary range for Pod IPs (VPC-native)"
  type        = string
  default     = "10.4.0.0/14"
  nullable    = false
}

variable "services_cidr" {
  description = "Secondary range for Service IPs"
  type        = string
  default     = "10.8.0.0/20"
  nullable    = false
}

variable "create_proxy_only_subnet" {
  description = "Create the regional proxy-only subnet used by regional Envoy-based load balancers (internal Gateways, regional Application Load Balancers)"
  type        = bool
  default     = true
  nullable    = false
}

variable "proxy_only_subnet_cidr" {
  description = "CIDR of the proxy-only subnet; must not overlap the other ranges"
  type        = string
  default     = "10.16.0.0/23"
  nullable    = false
}

variable "nat_ip_allocation" {
  description = "Cloud NAT egress IPs: auto (Google-managed, may change) or static (reserved, for third-party allowlists)"
  type        = string
  default     = "auto"
  nullable    = false

  validation {
    condition     = contains(["auto", "static"], var.nat_ip_allocation)
    error_message = "nat_ip_allocation must be \"auto\" or \"static\"."
  }
}

variable "nat_static_ip_count" {
  description = "Number of static NAT IPs when nat_ip_allocation is static"
  type        = number
  default     = 1
  nullable    = false
}
