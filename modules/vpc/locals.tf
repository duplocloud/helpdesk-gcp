locals {
  # <cluster_name>-<purpose>, as in the AWS repo (63 characters max; longer names keep a hash of the full name).
  names = { for k, v in {
    vpc            = "${var.cluster_name}-vpc"
    subnet         = "${var.cluster_name}-private"
    pods           = "${var.cluster_name}-pods"
    services       = "${var.cluster_name}-services"
    proxy          = "${var.cluster_name}-proxy"
    router         = "${var.cluster_name}-router"
    nat            = "${var.cluster_name}-nat"
    allow_internal = "${var.cluster_name}-allow-internal"
  } : k => length(v) <= 63 ? v : "${substr(v, 0, 58)}-${substr(sha1(v), 0, 4)}" }

  pods_range_name     = local.names.pods
  services_range_name = local.names.services
}
