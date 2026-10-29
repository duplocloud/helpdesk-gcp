locals {
  # Workload → KSA name. Set explicitly: the chart default depends on the release name.
  workloads = merge(
    {
      backend = "${var.release_name}-backend"
      agent   = "${var.release_name}-duplo-agent"
    },
    var.helpdesk_analytics_collector_enabled ? { collector = "${var.release_name}-collector" } : {},
  )

  # Project roles per workload; the collector needs none.
  workload_roles = {
    backend = ["roles/iam.serviceAccountTokenCreator", "roles/viewer", "roles/container.viewer"]
    agent   = ["roles/aiplatform.user", "roles/iam.serviceAccountTokenCreator"]
  }

  workload_role_grants = merge([
    for workload, roles in local.workload_roles : {
      for role in roles : "${workload}/${role}" => { workload = workload, role = role }
    }
  ]...)

  # Workload Identity bindings, plus backend impersonation of external SAs.
  service_account_bindings = merge(
    { for workload, ksa in local.workloads : "workload-identity/${workload}" => {
      service_account = google_service_account.workload[workload].name
      role            = "roles/iam.workloadIdentityUser"
      member          = "serviceAccount:${var.workload_pool}[${var.namespace}/${ksa}]"
    } },
    { for email in var.backend_impersonate_service_accounts : "impersonation/${email}" => {
      service_account = "projects/-/serviceAccounts/${email}"
      role            = "roles/iam.serviceAccountTokenCreator"
      member          = google_service_account.workload["backend"].member
    } },
  )

  # Infra-derived values; `set` wins over both values files.
  wi_annotation = "iam\\.gke\\.io/gcp-service-account"
  infra_values = concat(
    [
      { name = "config.authFrontendBaseUrl", value = "https://${var.helpdesk_dns}" },
      { name = "config.authAllowedOrigins", value = "https://${var.helpdesk_dns}" },
      { name = "config.infraRegion", value = var.region },
      { name = "config.googleCloudProject", value = var.project_id },
      { name = "xterm.hostname", value = "https://${var.helpdesk_xterm_dns}" },
      { name = "gateway.staticIpName", value = var.gateway_ip_name },
      { name = "gateway.tls.certMap", value = var.certificate_map_name },
      { name = "gateway.tls.sslPolicy", value = var.ssl_policy_name },
      { name = "backend.serviceAccount.name", value = local.workloads.backend },
      { name = "backend.serviceAccount.annotations.${local.wi_annotation}", value = google_service_account.workload["backend"].email },
      { name = "duploAgent.serviceAccount.name", value = local.workloads.agent },
      { name = "duploAgent.serviceAccount.annotations.${local.wi_annotation}", value = google_service_account.workload["agent"].email },
      # `set` replaces the whole list.
      { name = "duploAgent.extraEnv[0].name", value = "CLOUD_PROVIDER" },
      { name = "duploAgent.extraEnv[0].value", value = "GCP" },
      { name = "duploAgent.extraEnv[1].name", value = "GOOGLE_CLOUD_PROJECT" },
      { name = "duploAgent.extraEnv[1].value", value = var.project_id },
      { name = "collector.enabled", value = tostring(var.helpdesk_analytics_collector_enabled) },
    ],
    var.helpdesk_analytics_collector_enabled ? [
      { name = "collector.product.instance", value = var.helpdesk_analytics_collector_app_instance },
      { name = "collector.serviceAccount.create", value = "true" },
      { name = "collector.serviceAccount.name", value = local.workloads.collector },
      # Required by the chart.
      { name = "collector.serviceAccount.irsaRoleArn", value = google_service_account.workload["collector"].email },
      { name = "collector.serviceAccount.annotations.${local.wi_annotation}", value = google_service_account.workload["collector"].email },
    ] : [],
  )

  default_values = file("${path.module}/values/default.yml")
}
