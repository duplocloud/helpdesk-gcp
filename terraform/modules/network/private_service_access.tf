# Private IPs for Google managed services.
resource "google_compute_global_address" "psa" {
  name          = "${local.vpc_name}-psa"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.psa_range_prefix_length
  network       = google_compute_network.this.id

  labels = { component = "network" }
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}
