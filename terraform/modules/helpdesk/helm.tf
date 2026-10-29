# In-cluster copy of the values files (has credentials).
resource "kubernetes_secret_v1" "values_yaml" {
  metadata {
    name      = "${var.release_name}-values"
    namespace = var.namespace
  }

  data = {
    "values.yml"          = local.default_values
    "values-override.yml" = var.values_override
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "helm_release" "helpdesk" {
  name       = var.release_name
  repository = "oci://quay.io/duplocloud"
  chart      = "helpdesk"
  version    = var.chart_version
  namespace  = var.namespace
  timeout    = 900

  # Certificate and LB take longer than the pods anyway.
  wait          = false
  wait_for_jobs = false

  # Later wins: default, override, then `set`.
  values = [local.default_values, var.values_override]
  set    = local.infra_values

  depends_on = [
    kubernetes_secret_v1.values_yaml,
    google_service_account_iam_member.this,
    google_project_iam_member.workload,
  ]
}
