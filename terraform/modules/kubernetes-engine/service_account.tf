# Logging, monitoring and image pulls only.
resource "google_service_account" "node" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-gke-node"
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
