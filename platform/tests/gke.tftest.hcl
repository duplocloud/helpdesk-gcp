mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = { email = "hd-gke-node@acme-prod.iam.gserviceaccount.com", member = "serviceAccount:hd-gke-node@acme-prod.iam.gserviceaccount.com" }
  }
}

# Plan-only runs first: they plan a fresh create (the apply run below leaves state that ignore_changes keeps).
run "no_default_node_pool_when_the_channel_default_supports_it" {
  command = plan

  module {
    source = "../modules/gke"
  }

  override_data {
    target = data.google_container_engine_versions.this
    values = { release_channel_default_version = { REGULAR = "1.36.4-gke.2046003", STABLE = "1.35.8-gke.1439001" } }
  }

  variables {
    project_id          = "acme-prod"
    region              = "us-central1"
    cluster_name        = "hd-gke"
    network_id          = "projects/acme-prod/global/networks/hd-gke-vpc"
    subnet_id           = "projects/acme-prod/regions/us-central1/subnetworks/hd-gke-private"
    pods_range_name     = "hd-gke-pods"
    services_range_name = "hd-gke-services"
  }

  assert {
    condition     = google_container_cluster.this.remove_default_node_pool == null && google_container_cluster.this.initial_node_count == 0
    error_message = "REGULAR's default (1.36.4-gke.2046003) creates the cluster without a default node pool."
  }
}

run "older_channel_default_removes_the_default_node_pool" {
  command = plan

  module {
    source = "../modules/gke"
  }

  override_data {
    target = data.google_container_engine_versions.this
    values = { release_channel_default_version = { REGULAR = "1.36.4-gke.1200000", STABLE = "1.35.8-gke.1439001" } }
  }

  variables {
    project_id          = "acme-prod"
    region              = "us-central1"
    cluster_name        = "hd-gke"
    network_id          = "projects/acme-prod/global/networks/hd-gke-vpc"
    subnet_id           = "projects/acme-prod/regions/us-central1/subnetworks/hd-gke-private"
    pods_range_name     = "hd-gke-pods"
    services_range_name = "hd-gke-services"
  }

  assert {
    condition     = google_container_cluster.this.remove_default_node_pool == true && google_container_cluster.this.initial_node_count == 1
    error_message = "A channel default older than 1.36.4-gke.1469000 (here a build below it) needs the default pool created and removed."
  }
}

# The gke module on its own: provider default_labels don't reach node VMs, so node_labels must.
run "node_vms_get_the_node_labels" {
  command = apply

  module {
    source = "../modules/gke"
  }

  variables {
    project_id          = "acme-prod"
    region              = "us-central1"
    cluster_name        = "hd-gke"
    network_id          = "projects/acme-prod/global/networks/hd-gke-vpc"
    subnet_id           = "projects/acme-prod/regions/us-central1/subnetworks/hd-gke-private"
    pods_range_name     = "hd-gke-pods"
    services_range_name = "hd-gke-services"
    node_labels         = { "cost-center" = "ops", "duplocloud-deployment" = "hd" }
  }

  assert {
    condition = google_container_node_pool.default.node_config[0].resource_labels == tomap({
      "cost-center"           = "ops"
      "duplocloud-deployment" = "hd"
      component               = "kubernetes-engine"
    })
    error_message = "Node VMs carry node_labels plus the component label."
  }
}
