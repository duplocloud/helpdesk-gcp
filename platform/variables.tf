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

# One object per layer: { mode, values, provides }.
#   mode     = "create" or "existing" (dns: "managed" | "certificate" | "external")
#   values   = module variables the user changed; everything else uses the module default
#   provides = identifiers of the adopted resource (adopt modes only)
variable "network" {
  description = "Network layer (module vpc)"
  type        = any
}

variable "cluster" {
  description = "Cluster layer (module gke)"
  type        = any
}

variable "buckets" {
  description = "Object storage layer (module gcs)"
  type        = any
}

variable "dns" {
  description = "Certificate and DNS layer (module dns)"
  type        = any
}

variable "common_tags" {
  description = "Labels added to every resource (lowercase keys and values)"
  type        = map(string)
  default     = {}
}
