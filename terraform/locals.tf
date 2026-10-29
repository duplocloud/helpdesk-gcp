data "google_project" "current" {
  depends_on = [google_project_service.apis]
}

locals {
  project_id         = var.project_id
  project_number     = data.google_project.current.number
  workload_pool      = "${var.project_id}.svc.id.goog"
  resource_prefix    = var.prefix
  gke_cluster_name   = coalesce(var.cluster_name, "gke-${var.prefix}")
  helpdesk_namespace = var.helm_namespace
  collector_instance = coalesce(var.helpdesk_analytics_collector_app_instance, var.prefix)

  # Provider default_labels; also set on node VMs.
  common_labels = merge({
    app         = "duplo-helpdesk"
    deployment  = var.prefix
    environment = var.environment
    managed_by  = "terraform"
  }, var.common_labels)
}
