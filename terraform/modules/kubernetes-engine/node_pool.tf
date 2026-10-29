resource "google_container_node_pool" "default" {
  name     = "np-${var.name_prefix}-default"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.this.name

  # Limits are totals across zones.
  node_locations = local.node_zones

  initial_node_count = 0

  autoscaling {
    total_min_node_count = var.node_min
    total_max_node_count = var.node_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # One node at a time; MongoDB is a single replica.
  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    image_type   = "COS_CONTAINERD"
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size
    disk_type    = var.node_disk_type

    service_account = google_service_account.node.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    kubelet_config {
      insecure_kubelet_readonly_port_enabled = "FALSE"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    resource_labels = merge(var.labels, { component = "kubernetes-engine" })

    labels = {
      "duplocloud.net/component" = "helpdesk"
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}
