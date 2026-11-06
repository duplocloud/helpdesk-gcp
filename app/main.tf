data "terraform_remote_state" "platform" {
  backend = "gcs"

  config = {
    bucket = var.state.bucket
    prefix = var.state.platform_key
  }
}

locals {
  platform_outputs = data.terraform_remote_state.platform.outputs

  # Fallbacks keep plan and destroy working while the platform state is partial or gone.
  platform = {
    cluster_name           = try(local.platform_outputs.cluster_name, "${var.deployment.name}-gke")
    name_prefix            = try(local.platform_outputs.name_prefix, "${var.deployment.name}-gke")
    cluster_endpoint       = try(local.platform_outputs.cluster_endpoint, "")
    cluster_ca_certificate = try(local.platform_outputs.cluster_ca_certificate, "")
    workload_pool          = try(local.platform_outputs.workload_pool, "${var.deployment.account_id}.svc.id.goog")
    network_name           = try(local.platform_outputs.network_name, "")
    bucket_name            = try(coalesce(local.platform_outputs.bucket_name), "")
    userdata_bucket_name   = try(coalesce(local.platform_outputs.userdata_bucket_name), "")
    certificate_map_name   = try(local.platform_outputs.certificate_map_name, "")
    dns_mode               = try(local.platform_outputs.dns_mode, "")
    dns_zone_name          = try(local.platform_outputs.dns_zone_name, "")
    dns_zone_project       = try(local.platform_outputs.dns_zone_project, "")
  }


  # Managed DNS: Terraform writes the A records into the zone. Otherwise dns_records lists them.
  managed_dns = local.platform.dns_mode == "managed"
}

resource "random_password" "jwt_shared_secret" {
  length  = 48
  special = false
}

resource "random_password" "mongodb_root_password" {
  length  = 32
  special = false
}

module "storage" {
  source = "../modules/storage"

  mode                          = var.storage.mode
  deployment_name               = var.deployment.name
  project_id                    = var.deployment.account_id
  network_name                  = local.platform.network_name
  filestore_ip                  = try(var.storage.provides.filestore_ip, null)
  filestore_share               = try(var.storage.provides.filestore_share, null)
  storage_class_name            = try(var.storage.values.storage_class_name, "${local.platform.name_prefix}-filestore")
  filestore_size                = try(var.storage.values.filestore_size, null)
  nfs_provisioner_chart_version = try(var.storage.values.nfs_provisioner_chart_version, null)
  nfs_provisioner_namespace     = try(var.storage.values.nfs_provisioner_namespace, null)
  nfs_server_disk_size          = try(var.storage.values.nfs_server_disk_size, null)
}

module "helpdesk" {
  source = "../modules/helpdesk"

  project_id            = var.deployment.account_id
  region                = var.deployment.region
  cluster_name          = local.platform.name_prefix
  deployment_name       = var.deployment.name
  workload_pool         = local.platform.workload_pool
  helpdesk_dns          = var.deployment.host
  helpdesk_xterm_dns    = var.deployment.xterm_host
  certificate_map_name  = local.platform.certificate_map_name
  bucket_name           = local.platform.bucket_name
  userdata_bucket_name  = local.platform.userdata_bucket_name
  dns_zone_name         = local.managed_dns ? local.platform.dns_zone_name : ""
  dns_zone_project      = local.platform.dns_zone_project
  secrets               = var.secrets
  jwt_shared_secret     = random_password.jwt_shared_secret.result
  mongodb_root_password = random_password.mongodb_root_password.result

  storage                              = module.storage.helpdesk_storage
  release_name                         = try(var.helpdesk.values.release_name, null)
  namespace                            = try(var.helpdesk.values.namespace, null)
  chart_version                        = try(var.helpdesk.values.chart_version, null)
  local_admin_email                    = try(var.helpdesk.values.local_admin_email, null)
  backend_image_tag                    = try(var.helpdesk.values.backend_image_tag, null)
  frontend_image_tag                   = try(var.helpdesk.values.frontend_image_tag, null)
  agent_image_tag                      = try(var.helpdesk.values.agent_image_tag, null)
  helpdesk_analytics_collector_enabled = try(var.helpdesk.values.helpdesk_analytics_collector_enabled, null)
  helpdesk_mcp_enabled                 = try(var.helpdesk.values.helpdesk_mcp_enabled, null)
  slack_backend_enabled                = try(var.helpdesk.values.slack_backend_enabled, null)
  slack_backend_image_tag              = try(var.helpdesk.values.slack_backend_image_tag, null)
  slack_helpdesk_default_agent         = try(var.helpdesk.values.slack_helpdesk_default_agent, null)
  slack_helpdesk_default_workspace     = try(var.helpdesk.values.slack_helpdesk_default_workspace, null)
  slack_app_portals                    = try(var.helpdesk.values.slack_app_portals, null)
  backend_impersonate_service_accounts = try(var.helpdesk.values.backend_impersonate_service_accounts, null)

  depends_on = [module.storage]
}
