# An adopted subnet's secondary ranges are reused when it has a Pod and a Service range; otherwise
# GKE adds new ones to it from the cluster's pods_cidr / services_cidr.
data "google_compute_subnetwork" "adopted" {
  count = local.create_network ? 0 : 1

  project = split("/", local.subnet_id)[1]
  region  = split("/", local.subnet_id)[3]
  name    = split("/", local.subnet_id)[5]
}

locals {
  project_id = var.deployment.account_id

  adopted_ranges = local.create_network ? [] : [for r in data.google_compute_subnetwork.adopted[0].secondary_ip_range : r.range_name]
  adopted_pods   = [for n in local.adopted_ranges : n if strcontains(lower(n), "pod")]
  adopted_svcs   = [for n in local.adopted_ranges : n if strcontains(lower(n), "svc") || strcontains(lower(n), "service")]
  adopted_pods_range = length(local.adopted_ranges) < 2 ? null : (
    length(local.adopted_pods) > 0 ? local.adopted_pods[0] : local.adopted_ranges[0]
  )
  adopted_services_range = length(local.adopted_ranges) < 2 ? null : (
    length(local.adopted_svcs) > 0 ? local.adopted_svcs[0] : [for n in local.adopted_ranges : n if n != local.adopted_pods_range][0]
  )

  create_network = var.network.mode == "create"
  create_cluster = var.cluster.mode == "create"
  create_buckets = var.buckets.mode == "create"
  create_dns     = contains(["managed", "external"], var.dns.mode)

  # Naming prefix for every created resource, as in the AWS repo (<deployment>-eks there): <cluster_name>-<purpose>.
  cluster_name = try(var.cluster.values.cluster_name, null) != null ? var.cluster.values.cluster_name : "${var.deployment.name}-gke"

  # Each value comes from the module in create mode, otherwise from what the adopt mode provides.
  network_id          = local.create_network ? module.vpc[0].network_id : try(var.network.provides.network_id, null)
  subnet_id           = local.create_network ? module.vpc[0].subnet_id : try(var.network.provides.subnet_id, null)
  pods_range_name     = local.create_network ? module.vpc[0].pods_range_name : local.adopted_pods_range
  services_range_name = local.create_network ? module.vpc[0].services_range_name : local.adopted_services_range

  gke_cluster_name       = local.create_cluster ? module.gke[0].cluster_name : try(var.cluster.provides.cluster_name, null)
  cluster_endpoint       = local.create_cluster ? module.gke[0].cluster_endpoint : try(var.cluster.provides.cluster_endpoint, null)
  cluster_ca_certificate = local.create_cluster ? module.gke[0].cluster_ca_certificate : try(var.cluster.provides.cluster_ca_certificate, null)
  workload_pool          = local.create_cluster ? module.gke[0].workload_pool : try(coalesce(var.cluster.provides.workload_pool), "${local.project_id}.svc.id.goog")
  node_service_account   = local.create_cluster ? module.gke[0].node_service_account : try(var.cluster.provides.node_service_account, "")

  bucket_name          = local.create_buckets ? module.gcs[0].bucket_name : try(var.buckets.provides.bucket_name, null)
  bucket_url           = local.create_buckets ? module.gcs[0].bucket_url : try(var.buckets.provides.bucket_url, null)
  userdata_bucket_name = local.create_buckets ? module.gcs[0].userdata_bucket_name : try(var.buckets.provides.userdata_bucket_name, null)
  userdata_bucket_url  = local.create_buckets ? module.gcs[0].userdata_bucket_url : try(var.buckets.provides.userdata_bucket_url, null)

  certificate_id                 = local.create_dns ? module.dns[0].certificate_id : try(var.dns.provides.certificate_id, null)
  certificate_map_name           = local.create_dns ? module.dns[0].certificate_map_name : try(var.dns.provides.certificate_map_name, null)
  certificate_validation_records = local.create_dns ? module.dns[0].validation_records : []
  dns_zone_name                  = local.create_dns ? module.dns[0].dns_zone_name : ""
  dns_zone_project               = local.create_dns ? module.dns[0].dns_zone_project : local.project_id
}

module "vpc" {
  source = "../modules/vpc"
  count  = local.create_network ? 1 : 0

  project_id               = local.project_id
  cluster_name             = local.cluster_name
  region                   = var.deployment.region
  subnet_cidr              = try(var.network.values.subnet_cidr, null)
  pods_cidr                = try(var.network.values.pods_cidr, null)
  services_cidr            = try(var.network.values.services_cidr, null)
  create_proxy_only_subnet = try(var.network.values.create_proxy_only_subnet, null)
  proxy_only_subnet_cidr   = try(var.network.values.proxy_only_subnet_cidr, null)
  nat_ip_allocation        = try(var.network.values.nat_ip_allocation, null)
  nat_static_ip_count      = try(var.network.values.nat_static_ip_count, null)

  depends_on = [google_project_service.apis]
}

module "gke" {
  source = "../modules/gke"
  count  = local.create_cluster ? 1 : 0

  project_id          = local.project_id
  region              = var.deployment.region
  cluster_name        = local.cluster_name
  network_id          = local.network_id
  subnet_id           = local.subnet_id
  pods_range_name     = local.pods_range_name
  services_range_name = local.services_range_name
  labels              = var.common_tags

  pods_cidr                  = try(var.cluster.values.pods_cidr, null)
  services_cidr              = try(var.cluster.values.services_cidr, null)
  release_channel            = try(var.cluster.values.release_channel, null)
  node_machine_type          = try(var.cluster.values.node_machine_type, null)
  node_min                   = try(var.cluster.values.node_min, null)
  node_max                   = try(var.cluster.values.node_max, null)
  node_zones                 = try(var.cluster.values.node_zones, null)
  node_disk_size             = try(var.cluster.values.node_disk_size, null)
  node_disk_type             = try(var.cluster.values.node_disk_type, null)
  master_authorized_cidrs    = try(var.cluster.values.master_authorized_cidrs, null)
  enable_dns_endpoint        = try(var.cluster.values.enable_dns_endpoint, null)
  deletion_protection        = try(var.cluster.values.deletion_protection, null)
  cmek_key                   = try(var.cluster.values.cmek_key, null)
  control_plane_logs_enabled = try(var.cluster.values.control_plane_logs_enabled, null)
  additional_admin_members   = try(var.cluster.values.additional_admin_members, null)

  depends_on = [google_project_service.apis]
}

module "gcs" {
  source = "../modules/gcs"
  count  = local.create_buckets ? 1 : 0

  project_id                = local.project_id
  deployment_name           = var.deployment.name
  region                    = var.deployment.region
  labels                    = var.common_tags
  lifecycle_enabled         = try(var.buckets.values.lifecycle_enabled, null)
  lifecycle_expiration_days = try(var.buckets.values.lifecycle_expiration_days, null)

  depends_on = [google_project_service.apis]
}

module "dns" {
  source = "../modules/dns"
  count  = local.create_dns ? 1 : 0

  project_id         = local.project_id
  cluster_name       = local.cluster_name
  helpdesk_dns       = var.deployment.host
  helpdesk_xterm_dns = var.deployment.xterm_host
  create_dns_records = var.dns.mode == "managed"
  dns_zone_name      = try(var.dns.values.dns_zone_name, null)
  dns_project_id     = try(var.dns.values.dns_project_id, null)
  labels             = var.common_tags

  depends_on = [google_project_service.apis]
}
