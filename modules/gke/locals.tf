locals {
  # <cluster_name>-<purpose>, as in the AWS repo. GCP limits: node pools 40 characters, service account ids 30;
  # a longer name keeps a hash of the full name (and the purpose at the end).
  node_pool_name = length("${var.cluster_name}-default-np") <= 40 ? "${var.cluster_name}-default-np" : "${substr(var.cluster_name, 0, 24)}-${substr(sha1(var.cluster_name), 0, 4)}-default-np"
  node_sa_id     = length("${var.cluster_name}-node") <= 30 ? "${var.cluster_name}-node" : "${substr(var.cluster_name, 0, 20)}-${substr(sha1(var.cluster_name), 0, 4)}-node"
  node_zones     = length(var.node_zones) > 0 ? var.node_zones : data.google_compute_zones.available.names
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}
