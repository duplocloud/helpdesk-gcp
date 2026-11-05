# Managed mode: the validation CNAMEs go into the Cloud DNS zone, so the certificate issues on its own.
data "google_dns_managed_zone" "this" {
  count = var.create_dns_records ? 1 : 0

  project = local.dns_project
  name    = var.dns_zone_name
}

resource "google_dns_record_set" "validation" {
  for_each = var.create_dns_records ? local.validation_records : {}

  project      = local.dns_project
  managed_zone = data.google_dns_managed_zone.this[0].name
  name         = each.value.name
  type         = each.value.type
  ttl          = 60
  rrdatas      = [each.value.value]
}
