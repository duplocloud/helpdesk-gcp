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

  # An adopted network names the VPC, the node subnet and the subnet's Pod and Service ranges (picked in the wizard).
  validation {
    condition = try(var.network.mode, "") == "create" || alltrue([
      for k in ["vpc_id", "subnet_id", "pods_range_name", "services_range_name"] : try(coalesce(var.network.provides[k]), "") != ""
    ])
    error_message = "network.mode \"existing\" needs network.provides.vpc_id, subnet_id, pods_range_name and services_range_name (the node subnet and its Pod and Service secondary ranges)."
  }

  validation {
    # Missing ranges (absent, null or "") are reported by the validation above; this one only compares two picked ranges.
    condition = (try(var.network.mode, "") == "create" || try(coalesce(var.network.provides.pods_range_name), "") == ""
    || try(coalesce(var.network.provides.pods_range_name), "") != try(coalesce(var.network.provides.services_range_name), ""))
    error_message = "network.provides.pods_range_name and services_range_name must be two different secondary ranges of the subnet."
  }

  validation {
    condition     = try(var.network.mode, "") == "create" || can(regex("^projects/[^/]+/regions/[^/]+/subnetworks/[^/]+$", var.network.provides.subnet_id))
    error_message = "network.provides.subnet_id must be a subnet path: projects/<project>/regions/<region>/subnetworks/<name>."
  }
}

variable "cluster" {
  description = "Cluster layer (module gke)"
  type        = any

  # An adopted cluster must be on the Network layer's VPC: Filestore and the Gateway attach to that VPC. The wizard
  # lists only those clusters and sends the cluster's VPC as provides.network_id; this checks it when present (inputs
  # saved by an older release have none and plan as before).
  validation {
    condition = (try(var.cluster.mode, "") != "existing" || try(var.cluster.provides.network_id, "") == "" || (
      try(var.network.mode, "") != "create"
      && try(regex("projects/.+", var.cluster.provides.network_id), var.cluster.provides.network_id) == try(regex("projects/.+", var.network.provides.vpc_id), "")
    ))
    error_message = "An adopted cluster must be on the network layer's VPC: use network.mode \"existing\" with network.provides.vpc_id equal to cluster.provides.network_id."
  }
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
