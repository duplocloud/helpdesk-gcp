# GKE Standard only; Autopilot is not supported.

# Authorized networks are opt-in; IAM guards the endpoint otherwise.
#trivy:ignore:GCP-0061
resource "google_container_cluster" "this" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region

  # Replaced by the node pool below.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_id
  subnetwork = var.subnet_id

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Unset: GKE default (REGULAR).
  dynamic "release_channel" {
    for_each = var.release_channel != "" ? [1] : []
    content {
      channel = var.release_channel
    }
  }

  datapath_provider = "ADVANCED_DATAPATH"

  private_cluster_config {
    enable_private_nodes = true
    # enable_private_endpoint omitted: provider bug with private_endpoint_subnetwork.
    private_endpoint_subnetwork = var.subnet_id
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = var.enable_dns_endpoint
    }
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized) > 0 ? [1] : []
    content {
      gcp_public_cidrs_access_enabled = false

      dynamic "cidr_blocks" {
        for_each = var.master_authorized
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  logging_config {
    enable_components = concat(
      ["SYSTEM_COMPONENTS", "WORKLOADS"],
      var.control_plane_logs_enabled ? ["APISERVER", "SCHEDULER", "CONTROLLER_MANAGER"] : [],
    )
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  workload_identity_config {
    workload_pool = var.workload_pool
  }

  addons_config {
    gce_persistent_disk_csi_driver_config {
      enabled = true # Persistent Disks
    }
    http_load_balancing {
      disabled = false # Gateway / Ingress
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  # ── Hardening ───────────────────────────────────────────────────────────────
  anonymous_authentication_config {
    mode = "LIMITED"
  }

  rbac_binding_config {
    enable_insecure_binding_system_authenticated   = false
    enable_insecure_binding_system_unauthenticated = false
  }

  secret_manager_config {
    enabled = true
    rotation_config {
      enabled           = true
      rotation_interval = "120s"
    }
  }

  dynamic "database_encryption" {
    for_each = var.cmek_key != "" ? [1] : []
    content {
      state    = "ENCRYPTED"
      key_name = var.cmek_key
    }
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  node_pool_defaults {
    node_config_defaults {
      insecure_kubelet_readonly_port_enabled = "FALSE"
    }
  }

  cost_management_config {
    enabled = true
  }

  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_window.start_time
      end_time   = var.maintenance_window.end_time
      recurrence = var.maintenance_window.recurrence
    }
  }

  resource_labels = { component = "kubernetes-engine", environment = var.environment }

  deletion_protection = var.deletion_protection

  lifecycle {
    ignore_changes = [initial_node_count]
  }

  depends_on = [google_kms_crypto_key_iam_member.cmek]
}
