mock_provider "google" {
  mock_data "google_compute_zones" {
    defaults = { names = ["us-central1-a", "us-central1-b", "us-central1-c"] }
  }
  mock_resource "google_compute_network" {
    defaults = { id = "projects/acme-prod/global/networks/hd-vpc" }
  }
  mock_resource "google_compute_subnetwork" {
    defaults = { id = "projects/acme-prod/regions/us-central1/subnetworks/hd-vpc-nodes-usc1" }
  }
}

override_module {
  target = module.gke
  outputs = {
    cluster_name           = "hd-gke"
    cluster_endpoint       = "203.0.113.10"
    cluster_ca_certificate = "Q0E="
    workload_pool          = "acme-prod.svc.id.goog"
    node_service_account   = "hd-gke-node@acme-prod.iam.gserviceaccount.com"
  }
}

override_resource {
  target = module.dns[0].google_certificate_manager_dns_authorization.this
  values = {
    dns_resource_record = [{ name = "_acme-challenge.helpdesk.example.com.", type = "CNAME", data = "abc.authorize.certificatemanager.goog." }]
  }
}

variables {
  deployment = {
    name       = "hd"
    region     = "us-central1"
    host       = "helpdesk.example.com"
    xterm_host = "helpdesk-xterm.example.com"
    account_id = "acme-prod"
  }
  network = { mode = "create", values = {}, provides = {} }
  cluster = { mode = "create", values = {}, provides = {} }
  buckets = { mode = "create", values = {}, provides = {} }
  dns     = { mode = "managed", values = { dns_zone_name = "example-com" }, provides = {} }
}

run "greenfield" {
  command = apply

  assert {
    condition     = length(module.vpc) == 1 && length(module.gke) == 1 && length(module.gcs) == 1 && length(module.dns) == 1
    error_message = "Every layer is created in greenfield."
  }
  assert {
    condition     = output.cluster_name == "hd-gke" && output.workload_pool == "acme-prod.svc.id.goog"
    error_message = "Cluster outputs come from the gke module."
  }
  assert {
    condition     = output.pods_range_name == "hd-gke-pods" && output.subnet_id == "projects/acme-prod/regions/us-central1/subnetworks/hd-vpc-nodes-usc1"
    error_message = "Network outputs come from the vpc module."
  }
  assert {
    condition     = output.dns_mode == "managed" && output.dns_zone_name == "example-com" && length(module.dns[0].validation_records) == 2
    error_message = "Managed DNS writes validation records into the zone."
  }
}

run "names_follow_the_aws_convention" {
  command = apply

  assert {
    condition = alltrue([
      output.name_prefix == "hd-gke",
      module.vpc[0].network_name == "hd-gke-vpc",
      module.vpc[0].services_range_name == "hd-gke-services",
      module.dns[0].certificate_map_name == "hd-gke-certmap",
      output.bucket_name == "hd-helpdesk-acme-prod",
      output.userdata_bucket_name == "hd-helpdesk-userdata-acme-prod",
    ])
    error_message = "Resources are named <cluster_name>-<purpose>; buckets <deployment>-helpdesk[-userdata]-<project>."
  }
}

run "long_names_stay_within_gcp_limits" {
  command = apply

  variables {
    deployment = {
      name       = "a-very-long-deployment-name-32ch"
      region     = "us-central1"
      host       = "helpdesk.example.com"
      xterm_host = "helpdesk-xterm.example.com"
      account_id = "a-thirty-character-project-id"
    }
  }

  assert {
    condition = alltrue([
      length(output.userdata_bucket_name) <= 63,
      length(module.vpc[0].network_name) <= 63,
      length(module.dns[0].certificate_map_name) <= 63,
      output.userdata_bucket_name != output.bucket_name,
    ])
    error_message = "Names over a GCP limit are shortened with a hash, never over the limit."
  }
}

run "existing_network" {
  command = apply

  variables {
    network = {
      mode   = "existing"
      values = {}
      provides = {
        network_id = "projects/acme-prod/global/networks/corp"
        subnet_id  = "projects/acme-prod/regions/us-central1/subnetworks/corp-usc1"
      }
    }
  }

  override_data {
    target = data.google_compute_subnetwork.adopted[0]
    values = {
      secondary_ip_range = [
        { range_name = "gke-services", ip_cidr_range = "10.70.0.0/20", reserved_internal_range = "" },
        { range_name = "gke-pods", ip_cidr_range = "10.60.0.0/14", reserved_internal_range = "" },
      ]
    }
  }

  assert {
    condition     = length(module.vpc) == 0 && output.network_id == "projects/acme-prod/global/networks/corp"
    error_message = "An adopted network creates nothing and passes through."
  }
  assert {
    condition     = output.pods_range_name == "gke-pods" && output.services_range_name == "gke-services"
    error_message = "The adopted subnet's Pod and Service ranges are found by name."
  }
}

run "existing_network_new_ranges" {
  command = apply

  variables {
    network = {
      mode     = "existing"
      values   = {}
      provides = { network_id = "projects/acme-prod/global/networks/corp", subnet_id = "projects/acme-prod/regions/us-central1/subnetworks/corp-usc1" }
    }
  }

  override_data {
    target = data.google_compute_subnetwork.adopted[0]
    values = {
      secondary_ip_range = [{ range_name = "legacy", ip_cidr_range = "10.80.0.0/20", reserved_internal_range = "" }]
    }
  }

  assert {
    condition     = output.pods_range_name == null && output.services_range_name == null
    error_message = "With fewer than two ranges on the adopted subnet, GKE creates them."
  }
}

run "existing_cluster" {
  command = apply

  variables {
    cluster = {
      mode   = "existing"
      values = {}
      provides = {
        cluster_name           = "corp-gke"
        cluster_endpoint       = "198.51.100.7"
        cluster_ca_certificate = "Q0E="
        workload_pool          = "acme-prod.svc.id.goog"
      }
    }
  }

  assert {
    condition     = length(module.gke) == 0 && output.cluster_name == "corp-gke" && output.cluster_endpoint == "198.51.100.7"
    error_message = "An adopted cluster creates nothing and passes through."
  }
}

run "existing_buckets" {
  command = apply

  variables {
    buckets = {
      mode     = "existing"
      values   = {}
      provides = { bucket_name = "corp-data", bucket_url = "gs://corp-data" }
    }
  }

  assert {
    condition     = length(module.gcs) == 0 && output.bucket_name == "corp-data" && output.userdata_bucket_name == null
    error_message = "Adopted buckets pass through; the user data bucket is optional."
  }
}

run "dns_external" {
  command = apply

  variables {
    dns = { mode = "external", values = {}, provides = {} }
  }

  assert {
    condition     = length(module.dns) == 1 && output.dns_zone_name == "" && length(output.certificate_validation_records) == 2
    error_message = "External DNS creates the certificate and emits its validation records."
  }
}

run "dns_certificate" {
  command = apply

  variables {
    dns = {
      mode     = "certificate"
      values   = {}
      provides = { certificate_map_name = "corp-certmap", certificate_id = "projects/acme-prod/locations/global/certificates/corp" }
    }
  }

  assert {
    condition     = length(module.dns) == 0 && output.certificate_map_name == "corp-certmap" && length(output.certificate_validation_records) == 0
    error_message = "An adopted certificate map creates nothing."
  }
}
