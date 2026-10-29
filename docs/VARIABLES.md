# Input Variables — DuploCloud AI Helpdesk on GCP

Complete reference for every variable in [`terraform/variables.tf`](../terraform/variables.tf).  
Defaults are shown exactly as declared; **required** variables have no default.

> For an architectural overview and a configuration narrative, see [ARCHITECTURE.md](ARCHITECTURE.md).  
> For the step-by-step deployment guide, see the [top-level README](../README.md).

---

## Project

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | `string` | **required** | GCP project ID to deploy into |
| `region` | `string` | **required** | GCP region (e.g. `us-central1`). The GKE cluster is regional |
| `credentials_file` | `string` | `""` | Path to a GCP service-account key JSON. Empty = Application Default Credentials (`gcloud auth application-default login`) |

---

## Deployment identity

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `prefix` | `string` | `"duplo-ai"` | Deployment name used in every resource name (`<prefix>-vpc`, `gke-<prefix>`, `<prefix>-backend`, …). 1–17 lowercase letters, digits and hyphens. Must start with a letter and end with a letter or digit |
| `environment` | `string` | `"production"` | Value of the `environment` label applied to every GCP resource |

---

## GKE Cluster

> **GKE Standard only.** Autopilot is not supported. The stack creates a regional cluster, with the
> control plane replicated across all zones in the region.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | `string` | `""` | GKE cluster name. Empty → `gke-<prefix>` |
| `release_channel` | `string` | `""` | GKE release channel: `RAPID`, `REGULAR`, `STABLE`, `EXTENDED`, or `UNSPECIFIED`. Empty → GKE default (`REGULAR`) |
| `gke_enable_dns_endpoint` | `bool` | `false` | Allow IAM-authorized `kubectl`/Terraform access via the DNS-based control-plane endpoint (reachable from any network, independent of `master_authorized_cidrs`). Set `true` in CI or when you don't control the egress IP |
| `gke_control_plane_logs_enabled` | `bool` | `true` | Send API server, scheduler and controller-manager logs to Cloud Logging (system and workload logs are always on) |
| `gke_deletion_protection` | `bool` | `false` | Prevent the cluster from being deleted by Terraform. Set `false` and apply before `terraform destroy` |
| `gke_maintenance_window` | `object` | Sat + Sun 03:00–11:00 UTC | Recurring window for GKE auto-upgrades. Fields: `start_time`, `end_time` (RFC 3339 UTC), `recurrence` (RRULE). Must leave ≥ 48 h free in any 32-day window |
| `cmek_key` | `string` | `""` | Cloud KMS key (`projects/…/locations/<region>/keyRings/…/cryptoKeys/…`) to encrypt Kubernetes Secrets in etcd (CMEK). Must be in the cluster's region. Empty → Google-managed encryption. Set before first apply if possible |

### Maintenance window default

```hcl
gke_maintenance_window = {
  start_time = "2026-01-03T03:00:00Z"   # Saturday 03:00 UTC
  end_time   = "2026-01-03T11:00:00Z"   # Saturday 11:00 UTC
  recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
}
```

### GKE addons enabled by the stack

| Add-on | Why |
|--------|-----|
| GCE Persistent Disk CSI driver | Persistent Volume Claims (`standard-rwo`) |
| HTTP load balancing | Required by Gateway API |
| Horizontal Pod Autoscaling | Default cluster add-on |
| Gateway API (`CHANNEL_STANDARD`) | `gke-l7-global-external-managed` Gateway class |
| Managed Prometheus | Cluster metrics |
| Secret Manager CSI add-on | Workload Secret access without env vars |
| Dataplane V2 (eBPF) | NetworkPolicy enforcement |

---

## Worker nodes

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `node_machine_type` | `string` | `"e2-standard-4"` | Machine type for worker nodes (4 vCPU, 16 GB RAM). Minimum recommended for production |
| `node_min` | `number` | `0` | Minimum **total** node count across all zones. `0` allows scale-to-zero when idle |
| `node_max` | `number` | `3` | Maximum **total** node count across all zones |
| `node_zones` | `list(string)` | `[]` | Zones the node pool spans. Empty → every zone in the region |
| `node_disk_size` | `number` | `50` | Boot disk size in GB |
| `node_disk_type` | `string` | `"pd-balanced"` | Boot disk type: `pd-standard`, `pd-balanced`, or `pd-ssd` |

> `node_min` and `node_max` are **totals across all zones**. GKE distributes nodes across zones automatically.  
> With `node_min = 0` the pool scales to zero when idle, saving cost. Set `node_min ≥ 1` for always-on capacity and faster cold starts.

---

## Networking

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `subnet_cidr` | `string` | `"10.0.0.0/20"` | Primary CIDR for the GKE node subnet (4094 node addresses) |
| `pods_cidr` | `string` | `"10.4.0.0/14"` | Secondary range for Pod IPs (VPC-native). `/14` supports ~260k pods |
| `services_cidr` | `string` | `"10.8.0.0/20"` | Secondary range for Service (ClusterIP) IPs |
| `proxy_only_subnet_cidr` | `string` | `"10.16.0.0/23"` | Regional proxy-only subnet for Gateway API / Envoy load balancers. Must not overlap any other range |
| `psa_range_prefix_length` | `number` | `20` | Prefix length of the Private Service Access range auto-allocated for managed services |
| `master_authorized_cidrs` | `list(object)` | `[]` | Restrict the control plane's public IP endpoint to these CIDRs. Each entry: `{ cidr_block = "x.x.x.x/y", display_name = "label" }`. Empty → no IP restriction (IAM still required). Always include the IP Terraform/kubectl runs from |
| `nat_ip_allocation` | `string` | `"auto"` | Cloud NAT egress IP mode: `"auto"` (Google-managed, may change) or `"static"` (fixed IPs for third-party allowlists) |
| `nat_static_ip_count` | `number` | `1` | Number of static NAT IPs to reserve when `nat_ip_allocation = "static"` |

---

## DNS and certificate

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `helpdesk_dns` | `string` | **required** | Primary hostname for the helpdesk UI (e.g. `helpdesk.example.com`) |
| `helpdesk_xterm_dns` | `string` | **required** | Hostname for the xterm terminal service (e.g. `helpdesk-xterm.example.com`) |
| `dns_managed_zone` | `string` | `""` | Cloud DNS managed zone **name** (not the domain) that serves both hostnames. When set, Terraform automatically creates the A records and certificate-validation CNAMEs. Empty → DNS is external: create the records from `terraform output dns_records` |
| `dns_project_id` | `string` | `""` | GCP project that owns `dns_managed_zone`, when the zone is in a different project than `project_id`. Empty → same project |

### DNS records created

When `dns_managed_zone` is set, Terraform creates:

| Type | Name | Points to |
|------|------|-----------|
| `A` | `<helpdesk_dns>.` | Reserved Gateway IP |
| `A` | `<helpdesk_xterm_dns>.` | Reserved Gateway IP |
| `CNAME` | Certificate authorization record for `helpdesk_dns` | Google-issued validation target |
| `CNAME` | Certificate authorization record for `helpdesk_xterm_dns` | Google-issued validation target |

Without `dns_managed_zone`, run `terraform output dns_records` and create these records at your DNS provider. The TLS certificate is issued only after both CNAMEs resolve.

---

## Helm chart

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `helm_chart_version` | `string` | `"0.2.24"` | `oci://quay.io/duplocloud/helpdesk` chart version |
| `helm_release_name` | `string` | `"duplo-ai-helpdesk"` | Helm release name; also the prefix of all chart Kubernetes objects (`<name>-backend`, `<name>-frontend`, …) |
| `helm_namespace` | `string` | `"duplo-helpdesk"` | Kubernetes namespace for the Helm release |
| `helm_values_override_file` | `string` | **required** | Path (relative to `terraform/`) to your chart values YAML. Must be valid YAML and must set `mongodb.auth.rootPassword`. Validated at `terraform plan` time. Copy from `values-override.example.yml` |

### Helm value layers (later wins)

| Layer | Source | Wins over |
|-------|--------|-----------|
| 1 — defaults | `modules/helpdesk/values/default.yml` | — |
| 2 — customer override | `helm_values_override_file` | layer 1 |
| 3 — infra values | Terraform `set {}` blocks | layers 1 and 2 |

**Layer 3 values cannot be overridden** in the customer file. They include: hostnames, Gateway IP, certificate map, SSL policy, Workload Identity SA annotations, `duploAgent.extraEnv`, and the analytics collector config.

---

## Application

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `backend_impersonate_service_accounts` | `list(string)` | `[]` | GSA emails in **other** projects the helpdesk backend may impersonate (`roles/iam.serviceAccountTokenCreator`). The backend can already impersonate any SA in `project_id` |
| `helpdesk_analytics_collector_enabled` | `bool` | `true` | Run the analytics collector, which reports usage metrics to the DuploCloud control plane for billing and reporting |
| `helpdesk_analytics_collector_app_instance` | `string` | `""` | Unique identifier for this deployment in usage reports. Empty → defaults to `prefix` (`"duplo-ai"`) |

---

## Labels

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `common_labels` | `map(string)` | `{}` | Extra GCP labels merged onto every resource that supports labels. Keys must match `^[a-z][a-z0-9_-]{0,62}$`; values `^[a-z0-9_-]{0,63}$` |

Default labels always applied (cannot be overridden via `common_labels`):

| Key | Value |
|-----|-------|
| `app` | `duplo-helpdesk` |
| `deployment` | value of `prefix` |
| `environment` | value of `environment` |
| `managed_by` | `terraform` |

---

## Required GCP APIs

These are enabled automatically by `terraform/services.tf` and left enabled on destroy:

| API | Used by |
|-----|---------|
| `compute.googleapis.com` | VPC, subnets, Cloud NAT, firewall, reserved IP, SSL policy |
| `container.googleapis.com` | GKE cluster, node pool |
| `iam.googleapis.com` | Service accounts |
| `iamcredentials.googleapis.com` | Workload Identity token generation |
| `servicenetworking.googleapis.com` | Private Service Access (VPC peering) |
| `aiplatform.googleapis.com` | Vertex AI model calls |
| `cloudresourcemanager.googleapis.com` | Project metadata reads |
| `serviceusage.googleapis.com` | API enablement |
| `file.googleapis.com` | Cloud Filestore API |
| `certificatemanager.googleapis.com` | Certificate Manager |
| `dns.googleapis.com` | Cloud DNS records |
| `logging.googleapis.com` | Cloud Logging |
| `monitoring.googleapis.com` | Cloud Monitoring / Managed Prometheus |
| `secretmanager.googleapis.com` | Secret Manager CSI add-on |

---

## Outputs

| Output | Description |
|--------|-------------|
| `network_id` | VPC network self-link |
| `network_name` | VPC network name |
| `subnet_name` | GKE node subnet name |
| `proxy_only_subnet_name` | Regional proxy-only subnet name |
| `nat_ips` | Static Cloud NAT egress IPs (empty when `nat_ip_allocation = "auto"`) |
| `gke_cluster_name` | GKE cluster name |
| `gke_cluster_endpoint` | GKE API server endpoint (without `https://`) |
| `gke_cluster_location` | Cluster region |
| `node_service_account_email` | Node pool service account email |
| `helpdesk_backend_gsa_email` | Workload Identity GSA for the helpdesk backend |
| `helpdesk_agent_gsa_email` | Workload Identity GSA for duplo-agent (Vertex AI) |
| `helpdesk_analytics_collector_gsa_email` | Workload Identity GSA for the analytics collector (`null` when disabled) |
| `dns_records` | List of DNS records to create: A records + certificate-validation CNAMEs (auto-created when `dns_managed_zone` is set) |
| `certificate_map_name` | Certificate Manager certificate map name |
| `gateway_ip_address` | Reserved global IP of the external Application Load Balancer |
