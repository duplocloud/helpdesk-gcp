output "network_id" {
  description = "VPC network ID (projects/<p>/global/networks/<name>)"
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.this.name
}

output "subnet_id" {
  description = "Node subnet ID (projects/<p>/regions/<r>/subnetworks/<name>)"
  value       = google_compute_subnetwork.nodes.id
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
  description = "Static Cloud NAT egress IPs (empty with nat_ip_allocation = auto)"
  value       = google_compute_address.nat[*].address
}
