# Contributing

## Development setup

```bash
git clone https://github.com/duplocloud/helpdesk-gcp.git
cd helpdesk-gcp/terraform

# Install tools (macOS / Homebrew)
brew install terraform tflint trivy

# Install tflint Google plugin
tflint --init

# Authenticate for local runs
gcloud auth application-default login
```

## Before opening a PR

Run all checks from the `terraform/` directory:

```bash
# Format
terraform fmt -recursive

# Validate (requires initialized providers — run terraform init first)
terraform init -backend=false
terraform validate

# Lint
tflint --init && tflint --recursive

# Security scan (skip .terraform/ to avoid scanning provider binaries)
trivy config --skip-dirs .terraform .
```

All four must pass with no errors before merging.

## What to commit / what not to commit

| ✅ Commit | ❌ Never commit |
|-----------|----------------|
| `*.tf` files | `terraform.tfvars` |
| `*.tf.example` / `*.example.yml` | `values-override.yml` |
| `docs/` | `backend.tf` |
| `terraform/.tflint.hcl` | `tfplan*`, `*.log`, `errored.tfstate` |
| `terraform/.terraform.lock.hcl` | `*-key.json`, `*-credentials.json` |
| | `.terraform/` directory |

The `terraform/.gitignore` covers most of these automatically.

## Making changes to variables

1. Add/edit the variable in `terraform/variables.tf`.
2. If it affects a module, propagate it through `terraform/main.tf` and the module's `variables.tf`.
3. Update `terraform/terraform.tfvars.example` with a commented default or example value.
4. Update `docs/VARIABLES.md` with the new row.

## Making changes to the Helm values defaults

Edit `terraform/modules/helpdesk/values/default.yml`. This file is applied as the first layer; the customer
override file wins, and infra-derived `set {}` values win over everything.

## Versioning

This repo follows the Helm chart version it deploys. Update `helm_chart_version` in `terraform/variables.tf`
when upgrading to a new chart release, and document breaking changes in the PR description.
