# DuploCloud AI Helpdesk on GCP

Terraform that deploys [DuploCloud AI Helpdesk](https://duplocloud.com) into your own Google Cloud
project with a single `terraform apply`. You provide a GCP project, two hostnames, a Google OAuth
client and a MongoDB password; Terraform builds everything else and gives you a working HTTPS URL.

> **GKE Standard only.** The stack creates a regional GKE Standard cluster. Autopilot is not supported.

## What gets deployed

- A custom VPC with one private subnet and Cloud NAT for egress
- A regional **GKE Standard** cluster with private nodes and an autoscaling node pool across all zones
- A global external Application Load Balancer (GKE Gateway API) on a reserved IP, with a
  Google-managed Certificate Manager certificate and DNS records in your Cloud DNS zone (or records
  to create elsewhere)
- Storage: Persistent Disks for application data and MongoDB
- The Helpdesk application (Helm chart `oci://quay.io/duplocloud/helpdesk`), using Vertex AI for AI
  features
- Workload Identity for every workload (no service account keys), plus control-plane and audit logging

## Repository layout

```
.
├── README.md                      ← you are here
├── docs/
│   ├── VARIABLES.md               All Terraform input variables and outputs
│   └── ARCHITECTURE.md            Architecture deep-dive, security controls, IAM
└── terraform/
    ├── README.md                  Terraform operations guide
    ├── main.tf                    Module wiring
    ├── services.tf                Required GCP API enablement
    ├── providers.tf               google / helm / kubernetes providers
    ├── locals.tf                  Derived locals
    ├── variables.tf               All input variables
    ├── outputs.tf                 All outputs
    ├── versions.tf                Terraform + provider version pins
    ├── backend.tf.example         GCS remote state template → copy to backend.tf
    ├── terraform.tfvars.example   Variable template → copy to terraform.tfvars
    ├── values-override.example.yml Helm chart values template → copy to values-override.yml
    └── modules/
        ├── network/               VPC, subnets, Cloud NAT, Private Service Access, firewall
        ├── kubernetes-engine/     Regional GKE Standard cluster + node pool
        ├── load-balancer/         Reserved IP, Certificate Manager, SSL policy, DNS
        └── helpdesk/              Workload Identity GSAs, Kubernetes namespace, Helm release
```

## Prerequisites

### Tools

| Tool | Version |
|------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.9 |
| [gcloud CLI](https://cloud.google.com/sdk/docs/install) | latest |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | ≥ 1.27 (optional, for inspection) |

### GCP resources

1. **A GCP project** with billing enabled and a principal (user or service account) that has the roles
   listed in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#iam-roles-required-to-deploy).
   The required APIs are enabled for you by `services.tf`.

2. **DNS for two hostnames**, e.g. `helpdesk.example.com` and `helpdesk-xterm.example.com`.
   Either a public **Cloud DNS managed zone** (Terraform creates the records), or any other DNS
   provider (you create the records from `terraform output dns_records`).

3. **A Google OAuth client** for sign-in. In Google Cloud Console →
   *APIs & Services* → *Credentials* → *Create credentials* → *OAuth 2.0 Client ID* → *Web application*:
   - Authorized JavaScript origin: `https://helpdesk.example.com`
   - Authorized redirect URI: `https://helpdesk.example.com/signin-google`

   Microsoft Entra ID is also supported; see
   [`values-override.example.yml`](terraform/values-override.example.yml).

4. **A GCS bucket for Terraform state** (created in step 1 of the quick start below).

5. **Anthropic models enabled in Vertex AI Model Garden** (optional)

## Quick start

```bash
# 1. Clone the repo and enter the terraform directory
git clone https://github.com/duplocloud/helpdesk-gcp.git
cd helpdesk-gcp/terraform

# 2. Authenticate
gcloud auth application-default login

# 3. Create the state bucket (once per project)
gcloud storage buckets create gs://helpdesk-tfstate-<project_id> \
  --location=<region> \
  --uniform-bucket-level-access \
  --public-access-prevention
gcloud storage buckets update gs://helpdesk-tfstate-<project_id> --versioning

# 4. Configure Terraform backend
cp backend.tf.example backend.tf
# Edit backend.tf: set bucket = "helpdesk-tfstate-<project_id>"

# 5. Configure infrastructure variables
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` — these four lines are the minimum:

```hcl
project_id         = "my-gcp-project"
region             = "us-central1"
helpdesk_dns       = "helpdesk.example.com"
helpdesk_xterm_dns = "helpdesk-xterm.example.com"

dns_managed_zone          = "example-com"       # Cloud DNS zone NAME; omit if DNS is elsewhere
helm_values_override_file = "values-override.yml"
```

```bash
# 6. Configure Helm chart values (app secrets)
cp values-override.example.yml values-override.yml
```

Edit `values-override.yml` — the minimum required keys:

```yaml
mongodb:
  auth:
    rootPassword: "..."              # openssl rand -base64 32

secrets:
  googleClientId: "1234-abc.apps.googleusercontent.com"
  googleClientSecret: "GOCSPX-..."

config:
  authSuperUsers: "you@example.com"  # your admin e-mail
```

```bash
# 7. Initialize and deploy
terraform init \
  -backend-config="bucket=helpdesk-tfstate-<project_id>" \
  -backend-config="prefix=helpdesk-gcp"

terraform apply
```

`apply` returns once the Helm release is submitted. The certificate and load balancer take a
further **10–20 minutes** to become active. Then open `https://helpdesk.example.com` and sign in
with Google.

### Verify the deployment

```bash
gcloud container clusters get-credentials \
  "$(terraform output -raw gke_cluster_name)" \
  --region <region> --project my-gcp-project

kubectl get pods,gateway -n duplo-helpdesk

# Check certificate provisioning status (replace <prefix> with your prefix value)
gcloud certificate-manager certificates describe cert-<prefix>-helpdesk \
  --format='value(managed.state)'
```

## Configuration

Two files, two purposes:

- **`terraform.tfvars`** — infrastructure settings: project, region, network CIDRs, cluster size, DNS,
  chart version. See [docs/VARIABLES.md](docs/VARIABLES.md) for the full reference and
  [`terraform.tfvars.example`](terraform/terraform.tfvars.example) for defaults.

- **`values-override.yml`** — Helm chart values applied on top of
  `modules/helpdesk/values/default.yml`: MongoDB password, sign-in providers, super-users, Slack and
  any other chart setting. See [`values-override.example.yml`](terraform/values-override.example.yml).

Values that Terraform derives from the infrastructure (hostnames, Gateway IP, certificate map,
Workload Identity annotations) **cannot** be overridden from the values file.

## Terraform state and secrets

State lives in the GCS bucket you pass to `terraform init`.

`terraform.tfvars` and `values-override.yml` contain secrets — **don't commit them** (both are in
`.gitignore`). Keep a copy somewhere safe; you need them to update or destroy the stack.

## Telemetry

The analytics collector is enabled by default. It reports product usage and billing
for this Helpdesk instance to the DuploCloud control plane. It reports under `var.prefix`
by default, or you can set a custom identifier:

```hcl
helpdesk_analytics_collector_app_instance = "my-helpdesk"   # default: var.prefix
```

To opt out:

```hcl
helpdesk_analytics_collector_enabled = false
```

## Cost

Main costs with the defaults: GKE cluster management fee, up to three `e2-standard-4` nodes
(the pool scales to zero when idle — set `node_min ≥ 1` for always-on capacity), Cloud NAT,
the global load balancer, and Persistent Disks. Vertex AI model usage is billed per token on top.
Check current pricing for your region.

## Removing everything

The load balancer tears down asynchronously. Follow this order to avoid a failed destroy:

```bash
cd terraform

# 1. Uninstall the Helm release
terraform destroy -target=module.helpdesk.helm_release.helpdesk

# 2. Destroy everything else
terraform destroy
```

If the VPC deletion fails with `already being used by … networkEndpointGroups/k8s1-…`, delete those
NEGs (`gcloud compute network-endpoint-groups list --filter='network~/<prefix>-vpc$'`) and retry.

## Troubleshooting

See [terraform/README.md](terraform/README.md#troubleshooting) for the full troubleshooting guide.
Common first-run issues:

| Symptom | Fix |
|---------|-----|
| `helm_values_override_file` validation error | File is missing, not valid YAML, or missing `mongodb.auth.rootPassword` |
| `redirect_uri_mismatch` from Google | Redirect URI in the OAuth client must be exactly `https://<helpdesk_dns>/signin-google` |
| HTTPS doesn't work right after apply | Certificate is provisioned asynchronously; check `managed.state` and wait for `ACTIVE` |
| Terraform can't reach the cluster | Add your IP to `master_authorized_cidrs`, or set `gke_enable_dns_endpoint = true` |
| Apply fails with an IAM error | IAM changes take time to propagate; re-run `terraform apply` |

## Further reading

- [docs/VARIABLES.md](docs/VARIABLES.md) — every Terraform variable and output
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — architecture deep-dive, security controls, resource naming, cost breakdown
- [terraform/README.md](terraform/README.md) — Terraform module layout, workload IAM, destroy order, troubleshooting
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to develop, lint and contribute changes
