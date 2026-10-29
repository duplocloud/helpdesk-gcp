locals {
  hostnames = {
    helpdesk = var.helpdesk_dns
    xterm    = var.helpdesk_xterm_dns
  }

  labels = { component = "load-balancer" }

  cloud_dns   = var.dns_managed_zone != ""
  dns_project = coalesce(var.dns_project_id, var.project_id)

  # Per hostname: A record and certificate authorization CNAME.
  dns_records = merge(
    { for key, host in local.hostnames : "${key}-a" => {
      name  = "${host}."
      type  = "A"
      ttl   = 300
      value = google_compute_global_address.gateway.address
    } },
    { for key, auth in google_certificate_manager_dns_authorization.this : "${key}-authorization" => {
      name  = auth.dns_resource_record[0].name
      type  = auth.dns_resource_record[0].type
      ttl   = 60
      value = auth.dns_resource_record[0].data
    } },
  )
}
