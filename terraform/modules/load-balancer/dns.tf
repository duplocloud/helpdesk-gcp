# Only when dns_managed_zone is set; otherwise see the dns_records output.
data "google_dns_managed_zone" "this" {
  count = local.cloud_dns ? 1 : 0

  project = local.dns_project
  name    = var.dns_managed_zone
}

resource "google_dns_record_set" "this" {
  for_each = local.cloud_dns ? local.dns_records : {}

  project      = local.dns_project
  managed_zone = data.google_dns_managed_zone.this[0].name
  name         = each.value.name
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = [each.value.value]
}
