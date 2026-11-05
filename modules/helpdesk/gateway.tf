# The external Gateway's IP is reserved up front, so the A records don't wait for the load balancer.
resource "google_compute_global_address" "gateway" {
  project = var.project_id
  name    = local.names.gateway
}

# TLS 1.2+ MODERN.
resource "google_compute_ssl_policy" "this" {
  project         = var.project_id
  name            = local.names.ssl_policy
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

# Managed DNS mode: A records in the Cloud DNS zone. Other modes emit them through dns_records.
resource "google_dns_record_set" "a" {
  for_each = var.dns_zone_name != "" ? { helpdesk = var.helpdesk_dns, xterm = var.helpdesk_xterm_dns } : {}

  project      = coalesce(var.dns_zone_project, var.project_id)
  managed_zone = var.dns_zone_name
  name         = "${each.value}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.gateway.address]
}
