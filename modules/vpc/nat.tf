# Egress for private nodes.
resource "google_compute_address" "nat" {
  count = var.nat_ip_allocation == "static" ? var.nat_static_ip_count : 0

  name    = "${substr(local.names.nat, 0, 56)}-ip-${count.index + 1}"
  project = var.project_id
  region  = var.region
}

resource "google_compute_router" "this" {
  name    = local.names.router
  project = var.project_id
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  name                               = local.names.nat
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.this.name
  nat_ip_allocate_option             = var.nat_ip_allocation == "static" ? "MANUAL_ONLY" : "AUTO_ONLY"
  nat_ips                            = google_compute_address.nat[*].self_link
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
