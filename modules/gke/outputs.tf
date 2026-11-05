output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

# With the DNS endpoint on, OpenTofu connects through it (Google-managed public certificate, so no CA).
output "cluster_endpoint" {
  description = "Control-plane host OpenTofu connects to: the DNS endpoint when enabled, else the IP endpoint (no scheme)"
  value       = var.enable_dns_endpoint ? google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint : google_container_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 cluster CA; empty with the DNS endpoint (it serves a publicly trusted certificate)"
  value       = var.enable_dns_endpoint ? "" : google_container_cluster.this.master_auth[0].cluster_ca_certificate
}

output "location" {
  description = "Cluster location (region)"
  value       = google_container_cluster.this.location
}

output "node_service_account" {
  description = "Service account email used by worker nodes"
  value       = google_service_account.node.email
}

output "dns_endpoint" {
  description = "DNS-based control-plane endpoint"
  value       = google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
}

output "workload_pool" {
  description = "Workload Identity pool (<project>.svc.id.goog)"
  value       = google_container_cluster.this.workload_identity_config[0].workload_pool
}

output "ip_endpoint" {
  description = "IP control-plane endpoint (reachable only from allowed networks)"
  value       = google_container_cluster.this.endpoint
}
