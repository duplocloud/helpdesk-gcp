locals {
  # Workload -> Kubernetes service account. Set explicitly: the chart default depends on the release name.
  workloads = merge(
    {
      backend = "${var.release_name}-backend"
      agent   = "${var.release_name}-duplo-agent"
    },
    var.helpdesk_analytics_collector_enabled ? { collector = "${var.release_name}-collector" } : {},
  )

  workload_roles = {
    backend = ["roles/iam.serviceAccountTokenCreator", "roles/viewer", "roles/container.viewer"]
    agent   = ["roles/aiplatform.user", "roles/iam.serviceAccountTokenCreator"]
  }

  workload_role_grants = merge([
    for workload, roles in local.workload_roles : {
      for role in roles : "${workload}/${role}" => { workload = workload, role = role }
    }
  ]...)

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

  buckets = compact([var.bucket_name, var.userdata_bucket_name])

  # <cluster_name>-<purpose>, as in the AWS repo (63 characters max; longer names keep a hash of the full name).
  # The NFS StorageClass is cluster-scoped, so the per-deployment prefix also keeps it from colliding.
  names = { for k, v in {
    gateway    = "${var.cluster_name}-gateway"
    ssl_policy = "${var.cluster_name}-ssl-policy"
    nfs        = "${var.cluster_name}-nfs"
  } : k => length(v) <= 63 ? v : "${substr(v, 0, 58)}-${substr(sha1(v), 0, 4)}" }

  # incluster: the chart's NFS server class, named here; filestore/existing: the class modules/storage names.
  storage_class_name = var.storage.mode == "incluster" ? local.names.nfs : var.storage.class_name

  # The chart's resource-name prefix, set explicitly (fullnameOverride) so the backend claim's name doesn't depend on
  # the chart's own rule. Same value that rule gives (release name, plus "-helpdesk" unless it has it), so existing
  # releases keep their names.
  fullname      = trimsuffix(substr(strcontains(var.release_name, "helpdesk") ? var.release_name : "${var.release_name}-helpdesk", 0, 63), "-")
  backend_claim = "${local.fullname}-backend"

  # Service account ids are limited to 30 characters: keep the purpose, hash the prefix when too long.
  sa_ids = { for k in keys(local.workloads) : k =>
    length("${var.cluster_name}-${k}") <= 30 ? "${var.cluster_name}-${k}" : "${substr(var.cluster_name, 0, 30 - length(k) - 6)}-${substr(sha1(var.cluster_name), 0, 4)}-${k}"
  }

  extra_env = [{ name = "Authentication__LocalAdminEmail", value = var.local_admin_email }]

  rendered_values = templatefile("${path.module}/templates/values.yml.tftpl", {
    project_id                       = var.project_id
    storage_mode                     = var.storage.mode
    storage_class_name               = local.storage_class_name
    backend_claim                    = local.backend_claim
    fullname                         = local.fullname
    filestore_size                   = var.storage.filestore_size
    nfs_server_disk_size             = var.storage.nfs_server_disk_size
    region                           = var.region
    deployment_name                  = var.deployment_name
    helpdesk_dns                     = var.helpdesk_dns
    helpdesk_xterm_dns               = var.helpdesk_xterm_dns
    gateway_ip_name                  = google_compute_global_address.gateway.name
    certificate_map_name             = var.certificate_map_name
    ssl_policy_name                  = google_compute_ssl_policy.this.name
    backend_ksa                      = local.workloads.backend
    backend_gsa                      = google_service_account.workload["backend"].email
    agent_ksa                        = local.workloads.agent
    agent_gsa                        = google_service_account.workload["agent"].email
    collector_enabled                = var.helpdesk_analytics_collector_enabled
    collector_ksa                    = lookup(local.workloads, "collector", "")
    collector_gsa                    = try(google_service_account.workload["collector"].email, "")
    backend_extra_env                = local.extra_env
    local_admin_email                = var.local_admin_email
    backend_image_tag                = var.backend_image_tag
    frontend_image_tag               = var.frontend_image_tag
    agent_image_tag                  = var.agent_image_tag
    helpdesk_mcp_enabled             = var.helpdesk_mcp_enabled
    slack_backend_enabled            = var.slack_backend_enabled
    slack_backend_image_tag          = var.slack_backend_image_tag
    slack_helpdesk_default_agent     = var.slack_helpdesk_default_agent
    slack_helpdesk_default_workspace = var.slack_helpdesk_default_workspace
    slack_app_portals                = var.slack_app_portals
  })

  # Secret values by key; they only reach Helm through set_sensitive.
  secret_values = merge(
    { for k, v in var.secrets : k => v },
    {
      jwt_shared_secret     = var.jwt_shared_secret
      mongodb_root_password = var.mongodb_root_password
    }
  )

  # Whether a secret is set is not itself secret; keeps the set_sensitive keys known.
  secret_present = { for k in nonsensitive(keys(local.secret_values)) : k => nonsensitive(length(local.secret_values[k]) > 0) }

  sensitive_candidates = [
    { path = "secrets.licensingToken", key = "licensing_token", on = true },
    { path = "secrets.jwtSharedSecret", key = "jwt_shared_secret", on = true },
    { path = "mongodb.auth.rootPassword", key = "mongodb_root_password", on = true },
    { path = "backend.extraEnv[${length(local.extra_env)}].value", key = "local_admin_password", on = true },
    { path = "slackBackend.envFromSecret.data.SLACK_APP_TOKEN", key = "slack_app_token", on = var.slack_backend_enabled },
    { path = "slackBackend.envFromSecret.data.SLACK_BOT_TOKEN", key = "slack_bot_token", on = var.slack_backend_enabled },
  ]

  sensitive_entries = [for c in local.sensitive_candidates : c if c.on && lookup(local.secret_present, c.key, false)]
}
