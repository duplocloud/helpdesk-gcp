# Internal traffic from node and Pod ranges.
#trivy:ignore:GCP-0072
#trivy:ignore:GCP-0074
resource "google_compute_firewall" "internal" {
  name    = "${local.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.this.id

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr, var.pods_cidr]
}
