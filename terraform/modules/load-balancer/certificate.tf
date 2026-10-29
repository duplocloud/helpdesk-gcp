# Per-project, so a hostname can be authorized in several projects.
resource "google_certificate_manager_dns_authorization" "this" {
  for_each = local.hostnames

  project = var.project_id
  name    = "dnsauth-${var.name_prefix}-${each.key}"
  domain  = each.value
  type    = "PER_PROJECT_RECORD"
  labels  = local.labels
}

# Changing a hostname replaces it; HTTPS is down until ACTIVE.
resource "google_certificate_manager_certificate" "this" {
  project = var.project_id
  name    = "cert-${var.name_prefix}-helpdesk"
  labels  = local.labels

  managed {
    domains            = values(local.hostnames)
    dns_authorizations = [for auth in google_certificate_manager_dns_authorization.this : auth.id]
  }

  depends_on = [google_dns_record_set.this]
}

resource "google_certificate_manager_certificate_map" "this" {
  project = var.project_id
  name    = "certmap-${var.name_prefix}-helpdesk"
  labels  = local.labels
}

resource "google_certificate_manager_certificate_map_entry" "this" {
  for_each = local.hostnames

  project      = var.project_id
  name         = "certmapentry-${var.name_prefix}-${each.key}"
  map          = google_certificate_manager_certificate_map.this.name
  hostname     = each.value
  certificates = [google_certificate_manager_certificate.this.id]
  labels       = local.labels
}
