resource "google_service_account" "workload" {
  for_each = local.workloads

  project      = var.project_id
  account_id   = "${var.name_prefix}-${each.key}"
  display_name = "Helpdesk ${each.key} (${var.namespace}/${each.value})"
}

resource "google_service_account_iam_member" "this" {
  for_each = local.service_account_bindings

  service_account_id = each.value.service_account
  role               = each.value.role
  member             = each.value.member
}

# Project-wide token creator is intended.
#trivy:ignore:GCP-0011
resource "google_project_iam_member" "workload" {
  for_each = local.workload_role_grants

  project = var.project_id
  role    = each.value.role
  member  = google_service_account.workload[each.value.workload].member
}
