# TLS 1.2+ MODERN. Unprefixed: one per project.
resource "google_compute_ssl_policy" "this" {
  project         = var.project_id
  name            = "ssl-policy-modern"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}
