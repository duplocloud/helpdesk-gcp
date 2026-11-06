terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
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
