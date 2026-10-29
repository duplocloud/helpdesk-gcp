output "gateway_ip_name" {
  description = "Name of the reserved global IP (gateway.staticIpName)"
  value       = google_compute_global_address.gateway.name
}

output "gateway_ip_address" {
  description = "Reserved global IP address of the external Gateway"
  value       = google_compute_global_address.gateway.address
}

output "certificate_map_name" {
  description = "Certificate map name (Gateway annotation networking.gke.io/certmap)"
  value       = google_certificate_manager_certificate_map.this.name
}

output "ssl_policy_name" {
  description = "SSL policy name (Gateway annotation networking.gke.io/ssl-policy)"
  value       = google_compute_ssl_policy.this.name
}

output "dns_records" {
  description = "DNS records the helpdesk needs: A records for both hostnames and the certificate's DNS authorization CNAMEs. Created automatically with a Cloud DNS zone; create them at your DNS provider otherwise"
  value       = [for record in values(local.dns_records) : { name = record.name, type = record.type, value = record.value }]
}
