locals {
  # <cluster_name>-<purpose>, as in the AWS repo. GCP limits: node pools 40 characters, service account ids 30;
  # a longer name keeps a hash of the full name (and the purpose at the end).
  node_pool_name = length("${var.cluster_name}-default-np") <= 40 ? "${var.cluster_name}-default-np" : "${substr(var.cluster_name, 0, 24)}-${substr(sha1(var.cluster_name), 0, 4)}-default-np"
  node_sa_id     = length("${var.cluster_name}-node") <= 30 ? "${var.cluster_name}-node" : "${substr(var.cluster_name, 0, 20)}-${substr(sha1(var.cluster_name), 0, 4)}-node"
  node_zones     = length(var.node_zones) > 0 ? var.node_zones : data.google_compute_zones.available.names

  # GKE 1.36.4-gke.1469000+ creates a cluster without a default node pool when initial_node_count is 0; older versions
  # need the deprecated create-then-remove. Decided from the channel's current default version in the region, not
  # from the channel name (rollouts are staggered); anything unreadable takes the older, always-valid path.
  # Version as one number, major.minor.patch-gke.build -> MMMmmmppp * 10^7 + build (builds have at most 7 digits).
  channel_default = try(data.google_container_engine_versions.this.release_channel_default_version[var.release_channel], "")
  channel_version = [for p in try(regex("^(\\d+)\\.(\\d+)\\.(\\d+)-gke\\.(\\d+)", local.channel_default), []) : tonumber(p)]
  no_default_pool = length(local.channel_version) == 4 && try(
    (local.channel_version[0] * 1000000 + local.channel_version[1] * 1000 + local.channel_version[2]) * 10000000 + local.channel_version[3] >= 10360041469000,
    false
  )
}

data "google_container_engine_versions" "this" {
  project  = var.project_id
  location = var.region
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}
