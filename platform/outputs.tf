output "name_prefix" {
  description = "Prefix of every resource this deployment creates (<cluster_name>-<purpose>, as in the AWS repo)"
  value       = local.cluster_name
}

output "network_name" {
  description = "VPC network name"
  value       = local.network_id == null ? null : reverse(split("/", local.network_id))[0]
}

output "vpc_id" {
  description = "VPC network ID (projects/<project>/global/networks/<name>)"
  value       = local.network_id
}

output "subnet_id" {
  description = "Node subnet ID"
  value       = local.subnet_id
}

output "pods_range_name" {
  description = "Pod secondary range name of the node subnet"
  value       = local.pods_range_name
}

output "services_range_name" {
  description = "Service secondary range name of the node subnet"
  value       = local.services_range_name
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = local.gke_cluster_name
}

output "cluster_endpoint" {
  description = "GKE control-plane endpoint (host, no scheme)"
  value       = local.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 cluster CA certificate"
  value       = local.cluster_ca_certificate
}

output "workload_pool" {
  description = "Workload Identity pool (<project>.svc.id.goog)"
  value       = local.workload_pool
}

output "node_service_account" {
  description = "Node service account email"
  value       = local.node_service_account
}

output "bucket_name" {
  description = "App data bucket name"
  value       = local.bucket_name
}

output "bucket_arn" {
  description = "App data bucket URL (gs://...); named as on AWS"
  value       = local.bucket_arn
}

output "userdata_bucket_name" {
  description = "User data bucket name"
  value       = local.userdata_bucket_name
}

output "userdata_bucket_arn" {
  description = "User data bucket URL (gs://...); named as on AWS"
  value       = local.userdata_bucket_arn
}

output "certificate_arn" {
  description = "Certificate Manager certificate ID; named as on AWS"
  value       = local.certificate_arn
}

output "certificate_map_name" {
  description = "Certificate map for the external Gateway"
  value       = local.certificate_map_name
}

output "certificate_validation_records" {
  description = "DNS authorization CNAMEs to create when dns is external"
  value       = local.certificate_validation_records
}

output "dns_zone_name" {
  description = "Cloud DNS zone name in managed mode, else empty"
  value       = local.dns_zone_name
}

output "dns_zone_project" {
  description = "Project owning the Cloud DNS zone"
  value       = local.dns_zone_project
}

output "dns_mode" {
  description = "managed, certificate or external"
  value       = var.dns.mode
}
