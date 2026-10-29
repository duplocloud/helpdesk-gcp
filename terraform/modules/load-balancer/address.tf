resource "google_compute_global_address" "gateway" {
  project = var.project_id
  name    = "${var.name_prefix}-gateway"
  labels  = local.labels
}
