# APIs the platform and app roots use; left enabled on destroy.
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "aiplatform.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "file.googleapis.com",
    "storage.googleapis.com",
    "certificatemanager.googleapis.com",
    "dns.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  project            = var.deployment.account_id
  service            = each.value
  disable_on_destroy = false
}
