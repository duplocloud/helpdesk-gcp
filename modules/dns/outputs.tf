output "certificate_id" {
  description = "Certificate Manager certificate ID (projects/<p>/locations/global/certificates/<name>)"
  value       = google_certificate_manager_certificate.this.id
}

output "certificate_map_name" {
  description = "Certificate map the external Gateway uses (networking.gke.io/certmap)"
  value       = google_certificate_manager_certificate_map.this.name
}

output "validation_records" {
  description = "DNS authorization CNAMEs that let the certificate issue"
  value       = values(local.validation_records)
}

output "dns_zone_name" {
  description = "Cloud DNS zone name used in managed mode; empty otherwise"
  value       = var.create_dns_records ? var.dns_zone_name : ""
}

output "dns_zone_project" {
  description = "Project owning the Cloud DNS zone"
  value       = local.dns_project
}
