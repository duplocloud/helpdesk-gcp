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
  }

  assert {
    condition     = kubernetes_storage_class_v1.filestore[0].parameters == tomap({ tier = "standard", network = "hd-vpc", "connect-mode" = "DIRECT_PEERING" })
    error_message = "The class is Basic HDD (the only tier) on the deployment VPC, with direct peering."
  }
  assert {
    condition     = kubernetes_storage_class_v1.filestore[0].reclaim_policy == "Retain" && output.helpdesk_storage.filestore_size == "100Gi"
    error_message = "Retain keeps the instance after a destroy; the size defaults to 100Gi."
  }
}
