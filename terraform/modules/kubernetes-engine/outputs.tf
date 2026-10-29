output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

output "cluster_endpoint" {
  description = "GKE cluster API endpoint (host, without https://)"
  value       = google_container_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
}

output "location" {
  description = "Cluster location (region)"
  value       = google_container_cluster.this.location
}

output "node_service_account_email" {
  description = "Service account email used by worker nodes"
  value       = google_service_account.node.email
}

output "dns_endpoint" {
  description = "DNS-based control-plane endpoint"
  value       = google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
}
