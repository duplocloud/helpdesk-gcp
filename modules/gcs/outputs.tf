output "bucket_name" {
  description = "App data bucket name"
  value       = google_storage_bucket.this["data"].name
}

output "bucket_url" {
  description = "App data bucket URL (gs://...)"
  value       = google_storage_bucket.this["data"].url
}

output "userdata_bucket_name" {
  description = "User data bucket name"
  value       = google_storage_bucket.this["userdata"].name
}

output "userdata_bucket_url" {
  description = "User data bucket URL (gs://...)"
  value       = google_storage_bucket.this["userdata"].url
}
