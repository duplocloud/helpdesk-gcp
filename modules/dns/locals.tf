locals {
  hostnames = {
    helpdesk = var.helpdesk_dns
    xterm    = var.helpdesk_xterm_dns
  }

  labels = merge(var.labels, { component = "dns" })

  # <cluster_name>-<purpose>, as in the AWS repo (63 characters max; longer names keep a hash of the full name).
  names = { for k, v in {
    cert               = "${var.cluster_name}-cert"
    certmap            = "${var.cluster_name}-certmap"
    "certmap-helpdesk" = "${var.cluster_name}-certmap-helpdesk"
    "certmap-xterm"    = "${var.cluster_name}-certmap-xterm"
    "dnsauth-helpdesk" = "${var.cluster_name}-dnsauth-helpdesk"
    "dnsauth-xterm"    = "${var.cluster_name}-dnsauth-xterm"
  } : k => length(v) <= 63 ? v : "${substr(v, 0, 58)}-${substr(sha1(v), 0, 4)}" }

  dns_project = coalesce(var.dns_project_id, var.project_id)

  # The certificate's DNS authorization CNAMEs, one per hostname.
  validation_records = { for key, auth in google_certificate_manager_dns_authorization.this : key => {
    name  = auth.dns_resource_record[0].name
    type  = auth.dns_resource_record[0].type
    value = auth.dns_resource_record[0].data
  } }
}
