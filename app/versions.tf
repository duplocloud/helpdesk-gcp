terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}

provider "google" {
  project = var.deployment.account_id
  region  = var.deployment.region

  default_labels = merge(var.common_tags, {
    "duplocloud-deployment" = var.deployment.name
    "duplocloud-managed-by" = "cloud-deployment-agent"
  })
}

# Short-lived token from the same Google credentials OpenTofu runs with; no exec plugin.
data "google_client_config" "this" {}

provider "kubernetes" {
  host                   = "https://${local.platform.cluster_endpoint}"
  cluster_ca_certificate = local.platform.cluster_ca_certificate != "" ? base64decode(local.platform.cluster_ca_certificate) : null
  token                  = data.google_client_config.this.access_token
}

provider "helm" {
  # Cache in the working directory; XDG paths may be read-only.
  repository_config_path = "${path.cwd}/.helm/repositories.yaml"
  repository_cache       = "${path.cwd}/.helm/cache"

  kubernetes = {
    host                   = "https://${local.platform.cluster_endpoint}"
    cluster_ca_certificate = local.platform.cluster_ca_certificate != "" ? base64decode(local.platform.cluster_ca_certificate) : null
    token                  = data.google_client_config.this.access_token
  }
}
