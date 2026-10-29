resource "google_compute_network" "this" {
  name                    = local.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Nodes, Pods, Services and the control plane's private endpoint. Flow logs off.
#trivy:ignore:GCP-0029
#trivy:ignore:GCP-0076
resource "google_compute_subnetwork" "this" {
  name          = "${local.vpc_name}-nodes-${local.region_short}"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.subnet_cidr

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = local.pods_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = local.services_range_name
    ip_cidr_range = var.services_cidr
  }
}

# Proxy-only subnet for regional Envoy LBs.
#trivy:ignore:GCP-0075
resource "google_compute_subnetwork" "proxy_only" {
  name          = "proxy-subnet-${local.region_short}"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.proxy_only_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}
