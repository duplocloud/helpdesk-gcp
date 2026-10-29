output "network_id" {
  description = "VPC network ID"
  value       = module.network.network_id
}

output "network_name" {
  description = "VPC network name"
  value       = module.network.network_name
}

output "subnet_name" {
  description = "GKE node subnet name"
  value       = module.network.subnet_name
}

output "nat_ips" {
  description = "Static Cloud NAT egress IPs (empty when nat_ip_allocation = \"auto\")"
  value       = module.network.nat_ips
}

output "proxy_only_subnet_name" {
  description = "Name of the regional proxy-only subnet (Gateway API / regional LBs)"
  value       = module.network.proxy_only_subnet_name
}

output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = module.kubernetes_engine.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster API endpoint"
  value       = module.kubernetes_engine.cluster_endpoint
}

output "gke_cluster_location" {
  description = "GKE cluster location (region)"
  value       = module.kubernetes_engine.location
}

output "node_service_account_email" {
  description = "Service account email used by GKE worker nodes"
  value       = module.kubernetes_engine.node_service_account_email
}

output "helpdesk_backend_gsa_email" {
  description = "Google service account for the helpdesk backend (Workload Identity)"
  value       = module.helpdesk.backend_gsa_email
}

output "helpdesk_agent_gsa_email" {
  description = "Google service account for the helpdesk duplo-agent (Vertex AI)"
  value       = module.helpdesk.agent_gsa_email
}

output "helpdesk_analytics_collector_gsa_email" {
  description = "Google service account for the helpdesk analytics collector (null when the collector is disabled)"
  value       = module.helpdesk.collector_gsa_email
}

output "dns_records" {
  description = "DNS records the helpdesk needs (A records + certificate DNS authorization CNAMEs). Created automatically when dns_managed_zone is set; otherwise create them at your DNS provider"
  value       = module.load_balancer.dns_records
}

output "certificate_map_name" {
  description = "Certificate Manager certificate map used by the external Gateway"
  value       = module.load_balancer.certificate_map_name
}

output "gateway_ip_address" {
  description = "Reserved global IP of the external Gateway (helpdesk + xterm A records point here)"
  value       = module.load_balancer.gateway_ip_address
}
