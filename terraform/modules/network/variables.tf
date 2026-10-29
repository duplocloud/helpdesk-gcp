variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name_prefix" {
  description = "Deployment name; the VPC is <prefix>-vpc and the other network resources are <vpc>-<purpose>[-<region short id>]"
  type        = string
}

variable "region" {
  description = "GCP region for the subnet, router and NAT"
  type        = string
}

variable "subnet_cidr" {
  description = "Primary CIDR for the node subnet"
  type        = string
}

variable "pods_cidr" {
  description = "Secondary range CIDR for Pod IPs"
  type        = string
}

variable "services_cidr" {
  description = "Secondary range CIDR for Service IPs"
  type        = string
}

variable "proxy_only_subnet_cidr" {
  description = "CIDR for the regional proxy-only subnet (REGIONAL_MANAGED_PROXY) used by Gateway API / regional Envoy-based load balancers. Must not overlap subnet_cidr, pods_cidr or services_cidr."
  type        = string
  default     = "10.16.0.0/23"
}

variable "psa_range_prefix_length" {
  description = "Prefix length of the auto-allocated internal range reserved for Private Service Access (VPC peering with servicenetworking.googleapis.com)"
  type        = number
  default     = 20
}

variable "nat_ip_allocation" {
  description = "Cloud NAT external IPs: \"auto\" (allocated by Google) or \"static\" (reserved addresses)"
  type        = string
  default     = "auto"
}

variable "nat_static_ip_count" {
  description = "Number of static NAT IPs reserved when nat_ip_allocation = \"static\""
  type        = number
  default     = 1
}
