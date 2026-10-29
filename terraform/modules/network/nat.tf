# Egress for private nodes.
resource "google_compute_address" "nat" {
  count = var.nat_ip_allocation == "static" ? var.nat_static_ip_count : 0

  name    = "${local.vpc_name}-nat-${local.region_short}-${count.index + 1}"
  project = var.project_id
  region  = var.region
  labels  = { component = "network" }
}

resource "google_compute_router" "this" {
  name    = "${local.vpc_name}-router-${local.region_short}"
  project = var.project_id
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  name                               = "${local.vpc_name}-nat-${local.region_short}"
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
