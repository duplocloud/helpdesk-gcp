resource "helm_release" "helpdesk" {
  name       = var.release_name
  repository = "oci://quay.io/duplocloud"
  chart      = "helpdesk"
  version    = var.chart_version
  namespace  = var.namespace
  timeout    = 900

  # The certificate and load balancer take longer than the pods anyway.
  wait          = false
  wait_for_jobs = false

  values = [local.rendered_values]

  # The local admin password's env name sits next to its sensitive value in extraEnv.
  set = [{ name = "backend.extraEnv[${length(local.extra_env)}].name", value = "Authentication__LocalAdminPassword" }]

  # Helm's --set parser treats , \ { } specially, so they are escaped; type "string" stops coercion.
  set_sensitive = [for e in local.sensitive_entries : {
    name  = e.path
    value = replace(replace(replace(replace(local.secret_values[e.key], "\\", "\\\\"), ",", "\\,"), "{", "\\{"), "}", "\\}")
    type  = "string"
  }]

  depends_on = [
    kubernetes_namespace_v1.this,
    google_service_account_iam_member.this,
    google_project_iam_member.workload,
    google_storage_bucket_iam_member.backend,
  ]
}
