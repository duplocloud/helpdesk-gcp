output "backend_gsa_email" {
  description = "Google service account for the helpdesk backend (Workload Identity)"
  value       = google_service_account.workload["backend"].email
}

output "agent_gsa_email" {
  description = "Google service account for the helpdesk duplo-agent (Vertex AI inference)"
  value       = google_service_account.workload["agent"].email
}

output "collector_gsa_email" {
  description = "Google service account for the helpdesk analytics collector (null when the collector is disabled)"
  value       = try(google_service_account.workload["collector"].email, null)
}
