# Architecture and reference — DuploCloud AI Helpdesk on GCP

Modular Terraform codebase that deploys a production-ready **Google Cloud** infrastructure stack and the DuploCloud Helpdesk (`duplo-helpdesk`) Helm application.

> **GKE Standard only.** The stack creates a regional **GKE Standard** cluster with a Terraform-managed node pool.
> **Autopilot clusters are not supported.**

## Repository layout

```
helpdesk-gcp/
├── README.md                              Getting started guide
├── docs/
│   ├── ARCHITECTURE.md                    ← you are here
│   └── VARIABLES.md                       Every Terraform variable and output
└── terraform/
    ├── README.md                          Terraform operations guide
    ├── main.tf, services.tf, providers.tf Module wiring, required APIs, providers
    ├── variables.tf, outputs.tf, locals.tf
    ├── versions.tf                        Terraform + provider version pins
    ├── backend.tf.example                 GCS remote state template → copy to backend.tf
    ├── terraform.tfvars.example           Copy to terraform.tfvars
    ├── values-override.example.yml        Copy to values-override.yml (customer chart values)
    └── modules/
        ├── network/                       Custom VPC, private subnet, proxy-only subnet
        │   ├── vpc.tf                     VPC and subnets (node, proxy-only, secondary ranges)
        │   ├── private_service_access.tf  PSA range + peering (PSA)
        │   ├── nat.tf                     Cloud Router + Cloud NAT (+ optional static IPs)
        │   └── firewall.tf               Internal traffic allow rule
        ├── kubernetes-engine/             Regional GKE Standard (no Autopilot)
        │   ├── cluster.tf                 Private cluster, Dataplane V2, Workload Identity, Gateway API, hardening
        │   ├── node_pool.tf               Autoscaling node pool across zones
        │   ├── service_account.tf         Least-privilege node service account + IAM bindings
        │   └── kms.tf                     CMEK grant for the GKE service agent (optional)
        ├── load-balancer/                 Pre-cluster load-balancer resources
        │   ├── address.tf                 Reserved global IP
        │   ├── certificate.tf             DNS authorizations, certificate, certificate map + entries
        │   ├── ssl_policy.tf              TLS 1.2+ MODERN SSL policy
        │   └── dns.tf                     A + certificate-validation records (Cloud DNS, optional)
        └── helpdesk/                      Application layer
            ├── workload_identity.tf       Workload GSAs, Workload Identity bindings, project IAM roles
            ├── namespace.tf               Kubernetes namespace (Pod Security labels)
            ├── helm.tf                    Helm release + in-cluster Secret copy of values
            └── values/default.yml         Static chart defaults for GKE Standard
```

Every module also has `locals.tf`, `variables.tf`, `outputs.tf` and `versions.tf`.

## How the modules connect

```
services.tf ──enables APIs──► all modules (depends_on)
     │
     ├──► module.network              (VPC, subnets, Cloud NAT, PSA, firewall)
     │         │
     │         └──► module.kubernetes_engine   (GKE cluster + node pool)
     │                   │
     │                   └──► module.helpdesk  (Workload Identity GSAs, Helm release)
     │
     └──► module.load_balancer        (reserved IP, certificate, DNS — independent of GKE)
               │
               └──► module.helpdesk  (gateway_ip_name, certificate_map_name, ssl_policy_name)
```

`module.helpdesk` depends on `module.kubernetes_engine` so the GKE API endpoint is ready when the
Helm and Kubernetes providers connect.

## Networking

Worker nodes are **private** (no external IPs) and reach the internet through Cloud NAT (auto-allocated IPs, or
static with `nat_ip_allocation = "static"`). The cluster is always **GKE Standard**: one node pool spread over every
zone in the region (or `node_zones`), sized by `node_*`. Autopilot is not supported. GKE's defaults apply for the release
channel and in-cluster DNS (kube-dns). The app is exposed through the chart's **Gateway API** mode (`gke-l7-global-external-managed`): a global external Application Load Balancer pinned to a reserved IP, HTTPS via a Google-managed Certificate Manager certificate, HTTP → HTTPS redirect, TLS 1.2+ SSL policy. Workloads get cloud access through **Workload Identity** — no keys.

### Default IP ranges

| Range | CIDR | Used for |
|-------|------|----------|
| `subnet_cidr` | `10.0.0.0/20` | GKE nodes (4094 addresses) |
| `pods_cidr` | `10.4.0.0/14` | Pod IPs — VPC-native secondary range |
| `services_cidr` | `10.8.0.0/20` | Service (ClusterIP) IPs |
| `proxy_only_subnet_cidr` | `10.16.0.0/23` | Regional proxy-only subnet (Gateway API / Envoy LBs) |
| PSA range (`/20`) | auto-allocated | Google managed services (VPC peering) |

All ranges must be non-overlapping. If you have existing VPCs with peered ranges, adjust before the first apply.

## Resource Naming

Network resources are named after the VPC, `<prefix>-vpc`: `<vpc>-<purpose>`, plus the short region ID for
regional ones (`us-central1` → `usc1`, `europe-west4` → `euw4`, `northamerica-northeast1` → `nane1`). Other resources
follow the Google Cloud Foundation Toolkit style: resource-type abbreviation, then `prefix` (default `duplo-ai`), then
purpose.

| Resource | Name |
|---|---|
| VPC network | `<prefix>-vpc` |
| Subnets | `<prefix>-vpc-nodes-<region-id>` (secondary ranges `<prefix>-vpc-secondary1` for Pods, `<prefix>-vpc-secondary2` for Services), `proxy-subnet-<region-id>` |
| Private Service Access range | `<prefix>-vpc-psa` |
| Cloud Router / Cloud NAT | `<prefix>-vpc-router-<region-id>` / `<prefix>-vpc-nat-<region-id>` |
| Firewall rule | `<prefix>-vpc-allow-internal` |
| DNS logging policy | `<prefix>-vpc-dns-logging` |
| GKE cluster / node pool | `gke-<prefix>` (or `cluster_name`) / `np-<prefix>-default` |
| Service accounts | `<prefix>-gke-node`, `<prefix>-backend`, `<prefix>-agent`, `<prefix>-collector` (collector enabled only) |
| Gateway IP | `<prefix>-gateway` |
| Certificate / map / map entries | `cert-<prefix>-helpdesk` / `certmap-<prefix>-helpdesk` / `certmapentry-<prefix>-{helpdesk,xterm}` |
| DNS authorizations | `dnsauth-<prefix>-{helpdesk,xterm}` |
| SSL policy | `ssl-policy-modern` (one per project) |

Workload service account roles (project level): `<prefix>-backend` has
`iam.serviceAccountTokenCreator` (impersonate any service account in the project), `viewer` (read every resource in
the project, including VPC and IAM policies) and `container.viewer` (read GKE clusters and every Kubernetes object
except Secrets); `<prefix>-agent` has `aiplatform.user` and `iam.serviceAccountTokenCreator`; `<prefix>-collector`
(created only when the collector is enabled) has none. `backend_impersonate_service_accounts` adds impersonation of service accounts in other projects.

Kubernetes objects use the chart's names (`<helm_release_name>-*`, default `duplo-ai-helpdesk-*`). The Kubernetes namespace is `helm_namespace` (default `duplo-helpdesk`).

`prefix` is 1–17 characters so `<prefix>-collector` stays within GCP's 30-character service account ID limit.

## Security controls

| Control | Where | Details |
|---|---|---|
| No inbound from the internet | `modules/network` | Custom-mode VPC: no default allow rules, only internal traffic from the node and Pod ranges |
| GKE control plane + audit logging | `modules/kubernetes-engine` | API server, scheduler, controller-manager, system and workload logs; Kubernetes audit logs via Cloud Audit Logs |
| Private cluster | `modules/kubernetes-engine` | Private nodes; control plane public IP endpoint (IAM-authenticated) limited to `master_authorized_cidrs` when set; optional DNS-based, IAM-authorized endpoint (`gke_enable_dns_endpoint`); control plane private endpoint in the node subnet; anonymous access limited to health endpoints |
| Node hardening | `modules/kubernetes-engine` | Container-Optimized OS, kubelet read-only port off, auto-repair, dedicated least-privilege node SA |
| Cluster access control | `modules/kubernetes-engine` | Insecure RBAC bindings to `system:authenticated` / `system:unauthenticated` blocked; optional CMEK encryption of Secrets in etcd (`cmek_key`) |
| Workload isolation | `modules/kubernetes-engine`, `modules/helpdesk` | Workload Identity only (no SA keys), Dataplane V2 NetworkPolicy enforcement, security posture + OS vulnerability scanning, Secret Manager CSI add-on, Pod Security Standards `baseline` in audit + warn mode on the helpdesk namespace |
| Patching | `modules/kubernetes-engine` | Auto-upgrades (GKE's default release channel) inside a weekend maintenance window (`gke_maintenance_window`); node pool surge upgrades one node at a time with no capacity loss |
| Encryption in transit | `modules/load-balancer` | HTTPS-only Gateway (HTTP → 301), TLS 1.2+ `MODERN` SSL policy, Google-managed certificate |
| Change protection | `modules/kubernetes-engine` | Optional cluster deletion protection (`gke_deletion_protection`); resources carry `common_labels` |

**Pod Security Standards are not enforced.** The chart's `xterm` container runs privileged and `duplo-agent` adds
`SYS_ADMIN`/`NET_ADMIN`, both of which `baseline` rejects. Violations are recorded in the Kubernetes audit logs and
shown as warnings by Helm/kubectl; enforce `baseline` once the chart drops those privileges.

**Storage.** MongoDB and application workloads use the cluster's default StorageClass (`standard-rwo`, GCE Persistent Disk).

**Using a CMEK key** (`cmek_key`): create the key ring and key in the cluster's region first. The stack uses it
for Kubernetes Secrets in etcd and grants the GKE service agent `roles/cloudkms.cryptoKeyEncrypterDecrypter` on it, which needs `roles/cloudkms.admin` on the key for the deployer.
Set it before the first apply where possible: enabling it on an existing cluster is an in-place update that
re-encrypts every Secret. Disabling or destroying the key makes the Secrets unreadable.

**Labels.** Every Google resource that supports labels gets `app = "duplo-helpdesk"`, `deployment = <prefix>`,
`environment`, `managed_by = "terraform"` and a `component` label (`network`, `kubernetes-engine`,
`load-balancer`), plus anything in `common_labels`. Node VMs and disks carry them too.

**Linting.** `.tflint.hcl` enables the Terraform "all" preset and the Google ruleset:

```bash
tflint --init && tflint --recursive
trivy config --skip-dirs .terraform .
```

Intentional trivy exceptions are marked inline with `#trivy:ignore:<id>` and a reason.

The Terraform **state bucket** is created outside this configuration. Apply the same controls to it:

```bash
gcloud storage buckets update gs://<state-bucket> --versioning --public-access-prevention --uniform-bucket-level-access
```

Not covered here: Cloud Armor (WAF) on the Gateway, Binary Authorization, default-deny NetworkPolicies for
`duplo-helpdesk` (the chart ships only a MongoDB policy), VPC Service Controls, and project-wide log-based alerts for IAM, firewall and
audit-config changes (these belong at the project or organization level, not in a per-deployment stack).

## Prerequisites

| Tool        | Minimum Version |
|-------------|-----------------|
| Terraform   | 1.9.0           |
| gcloud CLI  | latest          |
| kubectl     | 1.27+           |
| Helm        | 3.x             |

- A GCP project with billing enabled. The stack enables the required APIs itself (`terraform/services.tf`).
- DNS for `helpdesk_dns` and `helpdesk_xterm_dns`: either a public **Cloud DNS managed zone** (`dns_managed_zone`,
  in this project or another one with `dns_project_id`), where Terraform creates the records, or any other DNS
  provider. Without a Cloud DNS zone, create the records from `terraform output dns_records` at your provider: two A
  records and two certificate-validation CNAMEs (one per hostname, unique to this project). The certificate is
  issued once the CNAMEs resolve.
- Authenticate with Application Default Credentials (`gcloud auth application-default login`) or set `credentials_file`.
- To use Anthropic models on Vertex AI, enable them for the project in Vertex AI Model Garden.
- The deployer identity needs the IAM roles listed in [IAM for the deployer](#iam-for-the-deployer) below.

## Quick Start

> See the full step-by-step guide in the [top-level README](../README.md). This section is a concise reference.

### 1. Create a Terraform state bucket

```bash
gcloud storage buckets create gs://helpdesk-tfstate-<project_id> --location=us-central1 \
  --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update gs://helpdesk-tfstate-<project_id> --versioning
```

### 2. Configure variables and the chart values override

```bash
cd terraform

cp backend.tf.example backend.tf
# Edit backend.tf: set bucket = "helpdesk-tfstate-<project_id>"

cp terraform.tfvars.example terraform.tfvars
# Fill in the REQUIRED section; everything else is optional with the default shown

cp values-override.example.yml values-override.yml
# Fill in the MongoDB root password and at least one login provider (see "Chart values" below)
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan and apply

```bash
terraform plan
terraform apply
```

The Helm release is installed with `wait = false`, so apply finishes once the release is submitted. The Certificate Manager certificate and the load balancer take a further ~10–20 minutes to become active.

### 5. Configure kubectl and verify

```bash
gcloud container clusters get-credentials <cluster_name> --region <region> --project <project_id>
# add --dns-endpoint if gke_enable_dns_endpoint = true

kubectl get nodes
kubectl get pods -n duplo-helpdesk                 # or your helm_namespace
kubectl get gateway,httproute -n duplo-helpdesk
gcloud certificate-manager certificates describe cert-<prefix>-helpdesk --format='value(managed.state)'
```

## Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `project_id` / `region` | yes | — | GCP project and region (regional cluster) |
| `credentials_file` | no | `""` | SA key JSON; empty = Application Default Credentials |
| `prefix` | no | `duplo-ai` | Deployment name used in resource names (1–17 chars) |
| `environment` | no | `production` | `environment` label on every resource |
| `cluster_name` | no | `gke-<prefix>` | GKE cluster name |
| `release_channel` | no | GKE default (`REGULAR`) | `RAPID`, `REGULAR`, `STABLE`, `EXTENDED` or `UNSPECIFIED` |
| `subnet_cidr` / `pods_cidr` / `services_cidr` | no | `10.0.0.0/20` / `10.4.0.0/14` / `10.8.0.0/20` | Node subnet and secondary ranges |
| `proxy_only_subnet_cidr` | no | `10.16.0.0/23` | Proxy-only subnet for regional Envoy LBs |
| `psa_range_prefix_length` | no | `20` | Private Service Access range |
| `gke_enable_dns_endpoint` | no | `false` | IAM-authorized control-plane access via the DNS endpoint (then used by kubectl and Terraform instead of the public IP) |
| `gke_deletion_protection` | no | `false` | Block cluster deletion; set `false` and apply before destroy |
| `master_authorized_cidrs` | no | `[]` (not set) | Limit the control plane's public IP endpoint to these networks; include where Terraform and kubectl run |
| `node_machine_type` | no | `e2-standard-4` | Worker node machine type |
| `node_min` / `node_max` | no | `0` / `3` | TOTAL nodes across all zones |
| `node_zones` | no | `[]` (all zones) | Zones the node pool spans |
| `node_disk_size` / `node_disk_type` | no | `50` / `pd-balanced` | Node boot disk |
| `nat_ip_allocation` / `nat_static_ip_count` | no | `auto` / `1` | Cloud NAT egress IPs; `static` reserves fixed addresses |
| `backend_impersonate_service_accounts` | no | `[]` | GSAs in other projects the backend may impersonate (it can already impersonate any in this project) |
| `helm_chart_version` | no | `0.2.24` | duplo-helpdesk Helm chart version |
| `helm_release_name` | no | `duplo-ai-helpdesk` | Helm release name; prefix of the chart's Kubernetes objects |
| `helm_namespace` | no | `duplo-helpdesk` | Kubernetes namespace for the release |
| `helm_values_override_file` | **yes** | — | Customer chart values file: MongoDB password, login, Slack, ... (see below) |
| `helpdesk_dns` / `helpdesk_xterm_dns` | yes | — | Hostnames for the app and xterm |
| `dns_managed_zone` | no | `""` | Cloud DNS zone **name** serving both hostnames; empty = external DNS (see `dns_records` output) |
| `dns_project_id` | no | `""` (= `project_id`) | Project owning `dns_managed_zone` |
| `helpdesk_analytics_collector_enabled` | no | `true` | Analytics collector: reports usage from MongoDB to the DuploCloud control plane (reporting, billing) |
| `helpdesk_analytics_collector_app_instance` | no | `""` | Identifier the deployment reports under; empty defaults to `prefix` |
| `gke_control_plane_logs_enabled` | no | `true` | API server, scheduler, controller-manager logs |
| `gke_maintenance_window` | no | Sat + Sun 03:00–11:00 UTC | Recurring window for auto-upgrades |
| `cmek_key` | no | `""` | Cloud KMS key (CMEK) for Secrets in etcd |
| `common_labels` | no | `{}` | Extra labels for every resource, merged over `app`, `deployment`, `managed_by` |

### Chart values

Terraform does not generate a values file. The release is installed from three layers, later ones winning:

1. **`terraform/modules/helpdesk/values/default.yml`** — static defaults for GKE Standard (Gateway API,
   MongoDB StatefulSet, …). Shipped with the stack; not templated.
2. **The customer's override file** (`helm_values_override_file`, **required**) — everything specific to the
   customer: the MongoDB root password (required; `terraform plan` fails without `mongodb.auth.rootPassword`), login
   providers (`secrets.google*` / `secrets.microsoft*`, at least one), `secrets.jwtSharedSecret`,
   `config.authSuperUsers`, the Slack backend, replica counts and any other chart setting. Start from
   `terraform/values-override.example.yml`. It contains credentials: keep it out of version control (`values-override.yml` is
   in `.gitignore`).
3. **Values Terraform sets from the infrastructure** (Helm `set`) — hostnames, project and region, Gateway IP /
   certificate map / SSL policy, Workload Identity service account names and annotations,
   `duploAgent.extraEnv`, and the analytics collector. These cannot be overridden by the override file.

```hcl
# In terraform/terraform.tfvars — path is relative to where Terraform runs (terraform/)
helm_values_override_file = "values-override.yml"
```

Lists in the override file replace the default list rather than merging. Editing the file changes the plan on the
next run. Both files are also stored in-cluster in a Kubernetes Secret named `<helm_release_name>-values`.

## IAM for the deployer

```bash
export PROJECT_ID="my-gcp-project"
export MEMBER="user:$(gcloud config get-value account)"   # or serviceAccount:<sa-email>

for ROLE in \
  roles/serviceusage.serviceUsageAdmin \
  roles/compute.admin \
  roles/container.admin \
  roles/iam.serviceAccountAdmin \
  roles/iam.serviceAccountUser \
  roles/resourcemanager.projectIamAdmin \
  roles/servicenetworking.networksAdmin \
  roles/dns.admin \
  roles/certificatemanager.owner
do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="${MEMBER}" --role="${ROLE}" --condition=None
done
```

| Role | Needed for |
|------|------------|
| `serviceusage.serviceUsageAdmin` | enabling the required APIs |
| `compute.admin` | VPC, subnets, router, NAT, firewall rules, reserved IP, SSL policy |
| `container.admin` | GKE cluster, node pool, and Kubernetes/Helm resources |
| `iam.serviceAccountAdmin` | node + workload service accounts and their Workload Identity bindings |
| `iam.serviceAccountUser` | attaching the node SA to the node pool (actAs) |
| `resourcemanager.projectIamAdmin` | project IAM bindings (node SA; workload service account roles) |
| `servicenetworking.networksAdmin` | Private Service Access peering |
| `dns.admin` | A and certificate-validation records (on `dns_project_id` when the zone is in another project) |
| `certificatemanager.owner` | certificate, DNS authorizations, certificate map |

## Outputs

| Output | Description |
|--------|-------------|
| `network_name` / `subnet_name` / `proxy_only_subnet_name` / `nat_ips` | Networking (`nat_ips` only with static NAT) |
| `dns_records` | Records to create at an external DNS provider (created automatically with `dns_managed_zone`) |
| `gke_cluster_name` / `gke_cluster_endpoint` / `gke_cluster_location` | Cluster info |
| `node_service_account_email` | Node SA |
| `helpdesk_*_gsa_email` | Workload Identity service accounts |
| `certificate_map_name` / `gateway_ip_address` | TLS + ingress IP |

## Cost

The main costs with the defaults:

| Resource | Notes |
|----------|-------|
| GKE cluster management | ~$72/month (regional cluster fee, always on) |
| Worker nodes | Up to 3 × `e2-standard-4`; scales to zero when idle (`node_min = 0`). Set `node_min ≥ 1` for always-on capacity |
| Cloud NAT | Per-hour + per-GB egress |
| Global external Application LB | Per-hour forwarding rule + per-GB processed |
| Persistent Disk | MongoDB boot disk and application storage |
| Vertex AI | Per-token billing for model calls |

Check current GCP pricing for your region. Use [GCP Pricing Calculator](https://cloud.google.com/products/calculator) for estimates.

## Destroy

Run all commands from the `terraform/` directory:

```bash
# 1. Uninstall the Helm release first so the chart cleans up its Kubernetes objects
terraform destroy -target=module.helpdesk.helm_release.helpdesk

# 2. Destroy everything else
terraform destroy
```

If `gke_deletion_protection = true`, lift it first:
```bash
terraform apply -var gke_deletion_protection=false
terraform destroy
```

If the VPC deletion fails with `already being used by … networkEndpointGroups/k8s1-…`, delete those NEGs first:
```bash
gcloud compute network-endpoint-groups list --filter="network~/<prefix>-vpc$"
# delete each one, then retry:
terraform destroy
```

> The GCS state bucket is not managed by this configuration. Enabled APIs are left on (`disable_on_destroy = false`).

## Troubleshooting

**Helm/kubectl can't reach the cluster**
Terraform and kubectl use the control plane's public IP endpoint. If `master_authorized_cidrs` is set, it only accepts those networks: add the network you run from. Alternatively set `gke_enable_dns_endpoint = true` to use the DNS-based endpoint, which needs only IAM (`container.clusters.connect`, included in `roles/container.admin` / `roles/container.developer`), and add `--dns-endpoint` to `get-credentials`.

**HTTPS doesn't work right after `terraform apply`**
The Certificate Manager certificate is provisioned asynchronously after the DNS authorization records propagate. Check:
```bash
gcloud certificate-manager certificates describe cert-<prefix>-helpdesk \
  --format='value(managed.state)'
```
Wait for `ACTIVE` (typically 10–20 minutes after the CNAMEs resolve).

**`redirect_uri_mismatch` from Google**
The redirect URI in your Google OAuth client must be exactly `https://<helpdesk_dns>/signin-google`.

**IAM errors on the first apply**
IAM propagation can lag seconds to minutes. Re-run `terraform apply`.

**`helm_values_override_file` validation error on `terraform plan`**
The file is missing, is not valid YAML, or does not set `mongodb.auth.rootPassword`.

## Linting and validation

```bash
cd terraform
terraform fmt -recursive
terraform validate
tflint --init && tflint --recursive
trivy config --skip-dirs .terraform .
```

`.tflint.hcl` enables the Terraform `all` preset and the Google plugin ruleset.
Intentional trivy exceptions are marked inline with `#trivy:ignore:<id>` and a reason comment.

Keep these files local only — never commit them:

| File | Why |
|------|-----|
| `terraform.tfvars` | Contains `project_id` and may contain `credentials_file` |
| `values-override.yml` | Contains MongoDB password, OAuth secrets, JWT secret |
| `backend.tf` | Contains GCS bucket name (infrastructure detail) |
| `tfplan*`, `*.log`, `errored.tfstate` | May contain secret values in plan output |
| `*-key.json` | Service account keys |
| `.terraform/` | Provider binaries and cached state |
