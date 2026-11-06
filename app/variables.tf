variable "deployment" {
  description = "The deployment: name, region, the two hostnames and the GCP project ID (account_id)"
  type = object({
    name       = string
    region     = string
    host       = string
    xterm_host = string
    account_id = string
  })
}

variable "state" {
  description = "Where the platform state lives. GCS keys by prefix, so platform_key is the platform root's prefix (deployments/<name>/platform)"
  type = object({
    bucket       = string
    region       = string
    platform_key = string
  })
}

# { mode, values, provides } per layer, as in the platform root.
variable "storage" {
  description = "Shared RWX storage layer (module storage): filestore (new instances via the Filestore CSI driver), existing (an existing Filestore share) or incluster (the chart's NFS server)"
  type        = any

  validation {
    condition     = contains(["filestore", "existing", "incluster"], try(var.storage.mode, ""))
    error_message = "storage.mode must be \"filestore\", \"existing\" or \"incluster\"."
  }

  validation {
    condition     = can(regex("^([1-9][0-9]*(Gi|Ti))?$", try(var.storage.values.filestore_size, "")))
    error_message = "storage.values.filestore_size must be a size in Gi or Ti, e.g. 100Gi or 1Ti."
  }

  # Basic HDD starts at 100 GiB; Filestore rejects less and the backend volume would stay Pending.
  validation {
    condition = !can(regex("^[1-9][0-9]*(Gi|Ti)$", try(var.storage.values.filestore_size, ""))) || (
      tonumber(regex("^[0-9]+", var.storage.values.filestore_size)) * (endswith(var.storage.values.filestore_size, "Ti") ? 1024 : 1) >= 100
    )
    error_message = "storage.values.filestore_size must be at least 100Gi (the Basic HDD minimum)."
  }
}

variable "helpdesk" {
  description = "Helpdesk layer (module helpdesk): create only"
  type        = any

  validation {
    condition     = try(var.helpdesk.mode, "") == "create"
    error_message = "helpdesk.mode must be \"create\"."
  }

  # Sign-in is the local admin only.
  validation {
    condition     = try(var.helpdesk.values.local_admin_email, "") != ""
    error_message = "Helpdesk needs helpdesk.values.local_admin_email (the admin who signs in first)."
  }

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", try(var.helpdesk.values.namespace, "helpdesk")))
    error_message = "helpdesk.values.namespace must be a Kubernetes name: lowercase letters, digits and '-', at most 63 characters."
  }

  # Each entry becomes an IAM binding on projects/-/serviceAccounts/<email>: anything but a service account email breaks
  # it. Any Google service account domain: user-managed (iam.), Compute Engine (developer.) and App Engine (appspot.).
  validation {
    condition = alltrue([
      for e in try(coalesce(var.helpdesk.values.backend_impersonate_service_accounts), []) :
      can(regex("^[a-z0-9][-a-z0-9]{0,62}@(([-a-z0-9]+\\.)+iam|developer|appspot)\\.gserviceaccount\\.com$", e))
    ])
    error_message = "helpdesk.values.backend_impersonate_service_accounts must be service account emails: <name>@<project>.iam.gserviceaccount.com, <number>-compute@developer.gserviceaccount.com or <project>@appspot.gserviceaccount.com."
  }
}

variable "secrets" {
  description = "Secret values (licensing_token, local_admin_password, slack_app_token, slack_bot_token); pass with TF_VAR_secrets only"
  type        = map(string)
  default     = {}
  sensitive   = true

  validation {
    condition     = lookup(var.secrets, "local_admin_password", "") != ""
    error_message = "Helpdesk needs secrets.local_admin_password (the local admin's password)."
  }
}

variable "common_tags" {
  description = "Labels added to every resource (lowercase keys and values)"
  type        = map(string)
  default     = {}
}
