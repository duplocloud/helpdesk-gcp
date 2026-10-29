provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = var.credentials_file != "" ? file(var.credentials_file) : null

  default_labels = local.common_labels
}

data "google_client_config" "default" {}

# DNS endpoint when enabled, else the IP endpoint.
locals {
  cluster_host           = var.gke_enable_dns_endpoint ? "https://${module.kubernetes_engine.dns_endpoint}" : "https://${module.kubernetes_engine.cluster_endpoint}"
  cluster_ca_certificate = var.gke_enable_dns_endpoint ? null : base64decode(module.kubernetes_engine.cluster_ca_certificate)
}

provider "helm" {
  # Cache in the working dir; XDG paths may be read-only.
  repository_config_path = "${path.cwd}/.helm/repositories.yaml"
  repository_cache       = "${path.cwd}/.helm/cache"
  kubernetes = {
    host                   = local.cluster_host
    cluster_ca_certificate = local.cluster_ca_certificate
    token                  = data.google_client_config.default.access_token
  }
}

provider "kubernetes" {
  host                   = local.cluster_host
  cluster_ca_certificate = local.cluster_ca_certificate
  token                  = data.google_client_config.default.access_token
}
