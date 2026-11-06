# App data and user data buckets, named as in the AWS repo (<deployment>-helpdesk[-userdata]-<account>).
# Bucket names are global, so they carry the project ID; over 63 characters keeps a hash of the full name.
locals {
  buckets = { for k, v in {
    data     = "${var.deployment_name}-helpdesk-${var.project_id}"
    userdata = "${var.deployment_name}-helpdesk-userdata-${var.project_id}"
  } : k => length(v) <= 63 ? v : "${substr(v, 0, 58)}-${substr(sha1(v), 0, 4)}" }
}

#trivy:ignore:GCP-0066
resource "google_storage_bucket" "this" {
  for_each = local.buckets

  name                        = each.value
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = { component = "storage" }

  versioning {
    enabled = true
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_enabled ? [1] : []
    content {
      action {
        type = "Delete"
      }
      condition {
        age = var.lifecycle_expiration_days
      }
    }
  }
}
