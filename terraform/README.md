# Terraform reference — DuploCloud AI Helpdesk on GCP

Operations guide for the Terraform in this directory: architecture, module layout, naming, security
controls, IAM, outputs and troubleshooting.

To deploy, start with the [top-level README](../README.md).
Every input variable is documented in [docs/VARIABLES.md](../docs/VARIABLES.md).

---

## Architecture

```
terraform/
├── main.tf                        Module wiring
├── services.tf                    Required GCP API enablement
├── providers.tf                   google / helm / kubernetes providers
├── locals.tf                      Derived locals (project number, cluster name, …)
├── variables.tf                   All input variables
├── outputs.tf                     All outputs
├── versions.tf                    Terraform + provider version constraints
├── backend.tf.example             GCS remote state template (copy → backend.tf, gitignored)
├── terraform.tfvars.example       Variable defaults template (copy → terraform.tfvars, gitignored)
├── values-override.example.yml    Helm chart values template (copy → values-override.yml, gitignored)
└── modules/
    ├── network/                   Custom VPC, private subnet, proxy-only subnet, NAT, firewall
    │   ├── vpc.tf                 VPC network and subnets (node, proxy-only, secondary ranges)
    │   ├── private_service_access.tf  Internal IP range + peering (PSA)
    │   ├── nat.tf                 Cloud Router + Cloud NAT (auto or static IPs)
    │   └── firewall.tf            Internal traffic allow rule
    ├── kubernetes-engine/         Regional GKE Standard cluster (no Autopilot)
    │   ├── cluster.tf             Private cluster, Dataplane V2, Workload Identity, Gateway API, hardening
    │   ├── node_pool.tf           Autoscaling node pool across all zones
    │   ├── service_account.tf     Least-privilege node service account
    │   └── kms.tf                 CMEK grant for the GKE service agent (optional)
    ├── load-balancer/             Pre-cluster load-balancer resources
    │   ├── address.tf             Reserved global IP
    │   ├── certificate.tf         DNS authorizations, Certificate Manager certificate + map
    │   ├── ssl_policy.tf          TLS 1.2+ MODERN SSL policy
    │   └── dns.tf                 A + certificate-validation records (Cloud DNS, optional)
    └── helpdesk/                  Application layer
        ├── workload_identity.tf   Workload GSAs, Workload Identity bindings, project IAM roles
        ├── namespace.tf           Kubernetes namespace (Pod Security labels)
        ├── helm.tf                Helm release + in-cluster Secret copy of values
        └── values/default.yml     Static chart defaults for GKE Standard
```

Every module also contains `locals.tf`, `variables.tf`, `outputs.tf` and `versions.tf`.

---

## How the modules connect

```
services.tf ──enables APIs──► all modules (depends_on)
     │
     ├──► module.network            (VPC, NAT, PSA, firewall)
     │         │
     │         └──► module.kubernetes_engine   (GKE cluster + node pool)
     │                   │
     │                   └──► module.helpdesk  (Workload Identity, Helm)
     │
     └──► module.load_balancer      (IP, certificate, DNS — independent of GKE)
               │
               └──► module.helpdesk (gateway_ip_name, certificate_map_name, ssl_policy_name)
```

`module.helpdesk` has `depends_on = [module.kubernetes_engine]` so the GKE API endpoint is ready when
the Helm and Kubernetes providers run.

---

## Resource naming

All resources follow the pattern `<prefix>-<resource-type>[-<region-id>]` (default prefix: `duplo-ai`).
Region IDs are condensed: `us-central1` → `usc1`, `europe-west4` → `euw4`, `northamerica-northeast1` → `nane1`.

| Resource | Name |
|---|---|
| VPC network | `<prefix>-vpc` |
| Node subnet | `<prefix>-vpc-nodes-<region-id>` |
| Pod secondary range | `<prefix>-vpc-secondary1` |
| Service secondary range | `<prefix>-vpc-secondary2` |
| Proxy-only subnet | `proxy-subnet-<region-id>` |
| Private Service Access range | `<prefix>-vpc-psa` |
| Cloud Router | `<prefix>-vpc-router-<region-id>` |
| Cloud NAT | `<prefix>-vpc-nat-<region-id>` |
| Firewall rule | `<prefix>-vpc-allow-internal` |
| GKE cluster | `gke-<prefix>` (or `cluster_name`) |
| Node pool | `np-<prefix>-default` |
| Node service account | `<prefix>-gke-node` |
| Workload GSAs | `<prefix>-backend`, `<prefix>-agent`, `<prefix>-collector` |
| Reserved Gateway IP | `<prefix>-gateway` |
| Certificate | `cert-<prefix>-helpdesk` |
| Certificate map | `certmap-<prefix>-helpdesk` |
| Certificate map entries | `certmapentry-<prefix>-helpdesk`, `certmapentry-<prefix>-xterm` |
| DNS authorizations | `dnsauth-<prefix>-helpdesk`, `dnsauth-<prefix>-xterm` |
| SSL policy | `ssl-policy-modern` (shared per project) |
| Kubernetes namespace | `helm_namespace` variable (default `duplo-helpdesk`) |
| Helm objects | `<helm_release_name>-*` (default `duplo-ai-helpdesk-*`) |

`prefix` is limited to 1–17 characters so `<prefix>-collector` stays within GCP's 30-character
service account ID limit.

---

## Security controls

| Control | Module | Details |
|---|---|---|
| No inbound from the internet | `network` | Custom-mode VPC: no default allow rules; only internal traffic from node and Pod ranges |
| Private nodes | `kubernetes-engine` | Nodes have no external IPs; outbound via Cloud NAT |
| Restricted control plane access | `kubernetes-engine` | `master_authorized_cidrs` limits the public IP endpoint; `gke_enable_dns_endpoint` enables the IAM-only DNS endpoint |
| Node hardening | `kubernetes-engine` | Container-Optimized OS; kubelet read-only port off; auto-repair; dedicated least-privilege node SA |
| No insecure RBAC bindings | `kubernetes-engine` | Blocks bindings to `system:authenticated` / `system:unauthenticated` |
| Workload Identity | `helpdesk` | No service-account keys; all cloud access via Workload Identity |
| NetworkPolicy enforcement | `kubernetes-engine` | Dataplane V2 enables in-cluster NetworkPolicy |
| Control-plane + audit logging | `kubernetes-engine` | API server, scheduler, controller-manager logs to Cloud Logging; Kubernetes audit logs via Cloud Audit Logs |
| Encryption in transit | `load-balancer` | HTTPS-only Gateway (HTTP → 301); TLS 1.2+ MODERN SSL policy; Google-managed certificate |
| Secrets encryption at rest | `kubernetes-engine` | Optional CMEK for Secrets in etcd (`cmek_key`) |
| Security posture scanning | `kubernetes-engine` | OS vulnerability and workload configuration scanning |
| Deletion protection | `kubernetes-engine` | Optional (`gke_deletion_protection`) |
| Auto-upgrades | `kubernetes-engine` | GKE managed; weekend maintenance window; surge upgrades (one node at a time) |
| Resource labelling | all | `app`, `deployment`, `environment`, `managed_by` on every resource; extended with `common_labels` |

> **Pod Security Standards are audited, not enforced.** The chart's `xterm` container runs privileged
> and `duplo-agent` adds `SYS_ADMIN`/`NET_ADMIN`, both of which `baseline` rejects. Violations appear
> in the audit log and as Helm/kubectl warnings. Enforce `baseline` once the chart drops those privileges.

---

## Storage

Application workloads and MongoDB use the cluster's default StorageClass (`standard-rwo`, GCE Persistent Disk).

---

## Workload Identity — GSAs and project roles

Three Google Service Accounts are created by `modules/helpdesk/workload_identity.tf` and bound to their
Kubernetes Service Accounts via Workload Identity. No SA keys are created.

| GSA | KSA | Project roles |
|-----|-----|---------------|
| `<prefix>-backend` | `<release>-backend` | `roles/iam.serviceAccountTokenCreator` (impersonate any SA in project), `roles/viewer`, `roles/container.viewer` |
| `<prefix>-agent` | `<release>-duplo-agent` | `roles/aiplatform.user`, `roles/iam.serviceAccountTokenCreator` |
| `<prefix>-collector` | `<release>-collector` | none (only created when `helpdesk_analytics_collector_enabled = true`) |

`backend_impersonate_service_accounts` adds `roles/iam.serviceAccountTokenCreator` on each listed SA in any project.

---

## IAM roles required to deploy

Run once as your user or CI service account:

```bash
export PROJECT_ID="my-gcp-project"
export MEMBER="user:$(gcloud config get-value account)"   # or serviceAccount:<sa>@...

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
| `serviceusage.serviceUsageAdmin` | Enabling the required APIs |
| `compute.admin` | VPC, subnets, router, NAT, firewall, reserved IP, SSL policy |
| `container.admin` | GKE cluster, node pool, Kubernetes and Helm resources |
| `iam.serviceAccountAdmin` | Node and workload service accounts, Workload Identity bindings |
| `iam.serviceAccountUser` | Attaching the node SA to the node pool (`actAs`) |
| `resourcemanager.projectIamAdmin` | Project-level IAM bindings for node SA and workload GSAs |
| `servicenetworking.networksAdmin` | Private Service Access peering |
| `dns.admin` | A and certificate-validation records (on `dns_project_id` when the zone is elsewhere) |
| `certificatemanager.owner` | Certificate, DNS authorizations, certificate map |

If `cmek_key` is set, also grant `roles/cloudkms.admin` on the key (needed to add the GKE service-agent
encrypter/decrypter binding).

---

## Outputs

| Output | Description |
|--------|-------------|
| `network_id` / `network_name` | VPC network |
| `subnet_name` | GKE node subnet |
| `proxy_only_subnet_name` | Regional proxy-only subnet |
| `nat_ips` | Static Cloud NAT egress IPs (empty when `nat_ip_allocation = "auto"`) |
| `gke_cluster_name` | GKE cluster name |
| `gke_cluster_endpoint` | GKE API server endpoint |
| `gke_cluster_location` | Cluster region |
| `node_service_account_email` | Node pool service account |
| `helpdesk_backend_gsa_email` | Workload Identity GSA for the backend |
| `helpdesk_agent_gsa_email` | Workload Identity GSA for duplo-agent |
| `helpdesk_analytics_collector_gsa_email` | Workload Identity GSA for the collector (`null` when disabled) |
| `dns_records` | DNS records to create (A + CNAMEs); auto-created with `dns_managed_zone` |
| `certificate_map_name` | Certificate Manager certificate map |
| `gateway_ip_address` | Reserved global IP for the external Gateway |

---

## Destroy

```bash
# 1. Remove the Helm release so the chart cleans up its own Kubernetes objects
terraform destroy -target=module.helpdesk.helm_release.helpdesk

# 2. Destroy everything else
terraform destroy
```

If `gke_deletion_protection = true`, lift it first:
```bash
terraform apply -var gke_deletion_protection=false
```

If the VPC deletion fails with `already being used by … networkEndpointGroups/k8s1-…`, delete those NEGs:
```bash
gcloud compute network-endpoint-groups list --filter="network~/<prefix>-vpc$"
# then delete each one and retry terraform destroy
```

---

## Troubleshooting

**Helm/kubectl can't reach the cluster**
Terraform and kubectl use the control plane's public IP endpoint by default.
If `master_authorized_cidrs` is set, add the network you run from.
Alternatively, set `gke_enable_dns_endpoint = true` and add `--dns-endpoint` to `get-credentials`.

**HTTPS doesn't work right after `terraform apply`**
The Certificate Manager certificate is provisioned asynchronously once the DNS CNAMEs propagate.
Check:
```bash
gcloud certificate-manager certificates describe cert-<prefix>-helpdesk \
  --format='value(managed.state)'
```
Wait for `ACTIVE` (typically 10–20 minutes after the CNAMEs resolve).

**`redirect_uri_mismatch` from Google**
The redirect URI in the Google OAuth client must be exactly `https://<helpdesk_dns>/signin-google`.

**IAM errors on the first apply**
IAM propagation can lag seconds to minutes. Re-run `terraform apply`.

**`helm_values_override_file` validation error**
The file is missing, is not valid YAML, or does not set `mongodb.auth.rootPassword`.

**Apply is slow / times out on the GKE cluster step**
GKE regional cluster creation takes 8–15 minutes. The Terraform `timeout` on `helm_release` is set to 900 s (15 min) to accommodate this. If you hit it, re-run `terraform apply`.

---

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
