output "release_name" {
  description = "Helm release name"
  value       = helm_release.helpdesk.name
}

output "namespace" {
  description = "Kubernetes namespace of the Helpdesk release"
  value       = helm_release.helpdesk.namespace
}

output "chart_version" {
  description = "Helpdesk chart version"
  value       = helm_release.helpdesk.version
}

output "release_status" {
  description = "Helm release status"
  value       = helm_release.helpdesk.status
}

output "gateway_ip" {
  description = "IP address of the external Gateway (both hostnames point here)"
  value       = google_compute_global_address.gateway.address
}

output "backend_gsa_email" {
  description = "Google service account of the backend (Workload Identity)"
  value       = google_service_account.workload["backend"].email
}

output "agent_gsa_email" {
  description = "Google service account of duplo-agent (Vertex AI)"
  value       = google_service_account.workload["agent"].email
}

output "collector_gsa_email" {
  description = "Google service account of the analytics collector (null when disabled)"
  value       = try(google_service_account.workload["collector"].email, null)
}

output "a_record_names" {
  description = "A records created in Cloud DNS (managed DNS mode); empty otherwise"
  value       = [for r in google_dns_record_set.a : r.name]
}

output "storage_class_name" {
  description = "StorageClass of Helpdesk's shared volumes (the chart creates it in filestore and incluster modes)"
  value       = local.storage_class_name
}

output "service_account_ids" {
  description = "Google service account ids by workload (<cluster_name>-<workload>, shortened to GCP's 30 characters)"
  value       = local.sa_ids
}

output "values" {
  description = "The rendered Helm values (secrets are not in them; they go through set_sensitive)"
  value       = local.rendered_values
}
