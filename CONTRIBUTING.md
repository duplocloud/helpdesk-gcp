# Contributing

## Development

```bash
tofu fmt -recursive
tflint --init && tflint --recursive --config "$PWD/.tflint.hcl"
cd platform && tofu init -backend=false && tofu validate && tofu test
cd ../app   && tofu init -backend=false && tofu validate && tofu test
```

CI runs the same commands (OpenTofu 1.13.2, TFLint 0.65.0) on every pull request.

## The contract

The DuploCloud Cloud Deployment agent pins releases of this repo, renders a setup wizard from the module
variables, and runs the two roots. Keep these properties, or the agent (and every other cloud's
equivalent repo) breaks:

- **Layout**: `platform/`, `app/`, `modules/<module>/` at the repo root. Roots reference modules as
  `../modules/<module>`. Each root has `versions.tf`, `backend.tf` with an empty `backend "gcs" {}` block,
  `variables.tf`, `main.tf`, `outputs.tf`, `tests/`, and a committed `.terraform.lock.hcl`.
- **Layers**: `network`, `cluster`, `buckets`, `dns` in `platform`; `storage`, `helpdesk` in `app`.
  Each is one root variable `{ mode, values, provides }`.
- **Modes**: `dns` uses `managed` (Cloud DNS), `certificate` (adopt a certificate map) and `external`.
  `create` runs the layer's module (`count = 1`). An adopt mode runs it with `count = 0` and
  reads `var.<layer>.provides.<name>` instead. Adopt modes never create anything that changes the adopted
  resource.
- **Values**: roots pass module arguments as `try(var.<layer>.values.<name>, null)` so an omitted value
  falls back to the module default. Every module variable that a user can set has a `description`.
- **Root inputs**: `deployment` `{ name, region, host, xterm_host, account_id }` (`account_id` is the GCP
  project ID), `state` (app root; `platform_key` is the platform root's GCS prefix),
  `secrets` (sensitive map, app root), `common_tags`.
- **Outputs**: the output names in `platform/outputs.tf` and `app/outputs.tf` are part of the contract.
  They follow `terraform-aws-helpdesk` where the concept is the same; the agent reads `certificate_arn`,
  `certificate_validation_records`, `dns_mode` (platform) and `load_balancer_hostname`, `helpdesk_url`,
  `dns_records`, `secrets`, `generated` (app).
- **No secrets on disk**: no `local_file`/`local_sensitive_file`; secrets only via `var.secrets`; generated
  secrets via `random_password`.
- **No `ui.yaml`** or other wizard files: the agent keeps its presentation layer in its own repo.

## Where this repo differs from `terraform-aws-helpdesk`

Deliberate, so keep them unless the AWS repo changes too:

- **Shared storage is in the `app` root** (`storage` layer). AWS creates EFS in `platform` and its storage class
  in `app` (`addons`). On GKE the Filestore instance is created by the CSI driver from a StorageClass, which is a
  Kubernetes object, so the whole layer belongs to the root that talks to the cluster. No `addons` layer: the
  Gateway API and the Filestore CSI driver are GKE add-ons turned on by the cluster module.
- **Validation blocks on the layer variables** (`platform/variables.tf`, `app/variables.tf`). They reject inputs
  that would otherwise plan and fail late (a missing secondary range, a cluster on another VPC); AWS has none.
- **Each module has its own `versions.tf`** with its `required_providers`, so a module can be tested on its own.
- **CI also runs TFLint** (`.tflint.hcl`).
- **Output and `provides` names** reuse the AWS names where the concept is the same (`vpc_id`, `certificate_arn`,
  `bucket_arn`, `load_balancer_hostname`), even though the GCP values are not ARNs or hostnames.

## Upgrade safety

Every release reaches existing deployments: the agent moves customers to the newly pinned release on their
next plan. A user always reviews the plan before anything is applied, but a release must not make that plan
destructive for no reason.

- Renaming or moving a resource (including into or out of a module, or changing a `count`/`for_each` key)
  needs a `moved` block.
- A new variable must have a `default` (and `nullable = false` unless null means something). A deployment
  created with an older release must plan without new inputs.
- Removing or renaming a variable or an output, changing a variable's type, or a provider major version
  bump is a **breaking change**: list it under "Breaking changes" in the release notes.
- Do not change defaults that would replace existing resources (instance types, CIDRs, names) without a
  breaking-change note.
- Keep the Helm `fullnameOverride` (modules/helpdesk `local.fullname`) stable: it names every Helpdesk
  Kubernetes resource, so a change renames them all on upgrade (new volume claims, a new MongoDB StatefulSet).

## Providers and lock files

After changing a `required_providers` block, regenerate the lock files for all platforms the agent runs on:

```bash
for r in platform app; do
  (cd $r && tofu init -backend=false -upgrade && tofu providers lock \
     -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64)
done
```

## Releases

Semver tags `vX.Y.Z` on `main`, never moved or deleted (the agent pins the tag and its commit SHA). The
GitHub release notes list, per module: variables added, removed or changed; outputs added or removed;
provider version changes; and a "Breaking changes" section (or "None").
