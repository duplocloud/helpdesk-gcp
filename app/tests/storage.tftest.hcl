mock_provider "kubernetes" {}
mock_provider "helm" {}

# The storage module on its own: OpenTofu owns a Basic HDD class on the deployment VPC, so a destroy removes it.
run "storage_module_owns_a_basic_hdd_class" {
  command = apply

  module {
    source = "../modules/storage"
  }

  variables {
    mode               = "filestore"
    network_name       = "hd-vpc"
    storage_class_name = "hd-gke-filestore"
    deployment_name    = "hd"
    project_id         = "acme-prod"
  }

  assert {
    condition = kubernetes_storage_class_v1.filestore[0].parameters == tomap({
      tier           = "standard"
      network        = "hd-vpc"
      "connect-mode" = "DIRECT_PEERING"
      labels         = "duplocloud-deployment=hd,duplocloud-managed-by=cloud-deployment-agent"
    })
    error_message = "The class is Basic HDD (the only tier) on the deployment VPC, with direct peering, and labels its instance."
  }
  assert {
    condition     = output.filestore_cleanup == "gcloud filestore instances list --project acme-prod --filter='labels.duplocloud-deployment=hd'"
    error_message = "A destroy keeps the instance (Retain); the output says how to find it."
  }
  assert {
    condition     = kubernetes_storage_class_v1.filestore[0].reclaim_policy == "Retain" && output.helpdesk_storage.filestore_size == "100Gi"
    error_message = "Retain keeps the instance after a destroy; the size defaults to 100Gi."
  }
}
