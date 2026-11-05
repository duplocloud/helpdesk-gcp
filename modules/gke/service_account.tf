# Logging, monitoring and image pulls only.
resource "google_service_account" "node" {
  project      = var.project_id
  account_id   = local.node_sa_id
  display_name = "GKE node SA for ${var.cluster_name}"
}

resource "google_project_iam_member" "node" {
  for_each = toset([
    "roles/container.defaultNodeServiceAccount",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node.email}"
}

# The deploying identity already has access; these are extra admins.
resource "google_project_iam_member" "admins" {
  for_each = toset(var.additional_admin_members)

  project = var.project_id
  role    = "roles/container.admin"
  member  = each.value
}
