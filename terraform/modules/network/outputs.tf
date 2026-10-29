output "network_id" {
  description = "VPC network ID (self-link)"
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.this.name
}

output "subnet_id" {
  description = "Subnet ID (self-link)"
  value       = google_compute_subnetwork.this.id
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.this.name
}

output "pods_range_name" {
  description = "Secondary range name for Pod IPs"
  value       = local.pods_range_name
}

output "services_range_name" {
  description = "Secondary range name for Service IPs"
  value       = local.services_range_name
}

output "nat_ips" {
  description = "Static Cloud NAT egress IPs (empty when nat_ip_allocation = \"auto\")"
  value       = google_compute_address.nat[*].address
}

output "proxy_only_subnet_name" {
  description = "Name of the regional proxy-only subnet (Gateway API / regional LBs)"
  value       = google_compute_subnetwork.proxy_only.name
}

output "psa_range_name" {
  description = "Name of the Private Service Access reserved range"
  value       = google_compute_global_address.psa.name
}

output "psa_connection" {
  description = "Private Service Access peering connection (servicenetworking.googleapis.com)"
  value       = google_service_networking_connection.psa.id
}

output "region_short" {
  description = "Short region ID used in regional resource names (e.g. usc1)"
  value       = local.region_short
}
