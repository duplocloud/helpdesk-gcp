module "network" {
  source = "./modules/network"

  project_id              = local.project_id
  name_prefix             = local.resource_prefix
  region                  = var.region
  subnet_cidr             = var.subnet_cidr
  pods_cidr               = var.pods_cidr
  services_cidr           = var.services_cidr
  proxy_only_subnet_cidr  = var.proxy_only_subnet_cidr
  psa_range_prefix_length = var.psa_range_prefix_length
  nat_ip_allocation       = var.nat_ip_allocation
  nat_static_ip_count     = var.nat_static_ip_count

  depends_on = [google_project_service.apis]
}

module "kubernetes_engine" {
  source = "./modules/kubernetes-engine"

  project_id      = local.project_id
  project_number  = local.project_number
  name_prefix     = local.resource_prefix
  cluster_name    = local.gke_cluster_name
  region          = var.region
  release_channel = var.release_channel
  environment     = var.environment
  workload_pool   = local.workload_pool

  enable_dns_endpoint        = var.gke_enable_dns_endpoint
  deletion_protection        = var.gke_deletion_protection
  control_plane_logs_enabled = var.gke_control_plane_logs_enabled

  cmek_key           = var.cmek_key
  maintenance_window = var.gke_maintenance_window

  labels = local.common_labels

  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name
  master_authorized   = var.master_authorized_cidrs

  node_machine_type = var.node_machine_type
  node_min          = var.node_min
  node_max          = var.node_max
  node_zones        = var.node_zones
  node_disk_size    = var.node_disk_size
  node_disk_type    = var.node_disk_type

  depends_on = [google_project_service.apis]
}

module "load_balancer" {
  source = "./modules/load-balancer"

  project_id         = local.project_id
  name_prefix        = local.resource_prefix
  helpdesk_dns       = var.helpdesk_dns
  helpdesk_xterm_dns = var.helpdesk_xterm_dns
  dns_managed_zone   = var.dns_managed_zone
  dns_project_id     = var.dns_project_id

  depends_on = [google_project_service.apis]
}

module "helpdesk" {
  source = "./modules/helpdesk"

  release_name  = var.helm_release_name
  project_id    = local.project_id
  region        = var.region
  name_prefix   = local.resource_prefix
  namespace     = local.helpdesk_namespace
  workload_pool = local.workload_pool

  backend_impersonate_service_accounts = var.backend_impersonate_service_accounts

  # Gateway
  helpdesk_dns         = var.helpdesk_dns
  helpdesk_xterm_dns   = var.helpdesk_xterm_dns
  gateway_ip_name      = module.load_balancer.gateway_ip_name
  certificate_map_name = module.load_balancer.certificate_map_name
  ssl_policy_name      = module.load_balancer.ssl_policy_name

  # Chart
  chart_version                             = var.helm_chart_version
  values_override                           = file(var.helm_values_override_file)
  helpdesk_analytics_collector_app_instance = local.collector_instance
  helpdesk_analytics_collector_enabled      = var.helpdesk_analytics_collector_enabled

  depends_on = [module.kubernetes_engine]
}
