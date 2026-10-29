locals {
  node_zones = length(var.node_zones) > 0 ? var.node_zones : data.google_compute_zones.available.names
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}
