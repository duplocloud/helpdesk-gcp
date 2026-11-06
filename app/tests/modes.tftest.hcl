mock_provider "google" {
  mock_data "google_client_config" {
    defaults = { access_token = "ya29.mock" }
  }
  mock_resource "google_compute_global_address" {
    defaults = { address = "34.120.0.10" }
  }
  mock_resource "google_service_account" {
    defaults = { email = "hd-backend@acme-prod.iam.gserviceaccount.com", member = "serviceAccount:hd-backend@acme-prod.iam.gserviceaccount.com", name = "projects/acme-prod/serviceAccounts/hd-backend@acme-prod.iam.gserviceaccount.com" }
  }
}
mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "random" {}

override_data {
  target = data.terraform_remote_state.platform
  values = {
    outputs = {
      cluster_name           = "hd-gke"
      cluster_endpoint       = "203.0.113.10"
      cluster_ca_certificate = "Q0E="
      workload_pool          = "acme-prod.svc.id.goog"
      network_name           = "hd-vpc"
      bucket_name            = "duplo-helpdesk-hd-acme-prod"
      userdata_bucket_name   = "duplo-helpdesk-hd-userdata-acme-prod"
      certificate_map_name   = "certmap-hd-helpdesk"
      dns_mode               = "external"
      dns_zone_name          = ""
      dns_zone_project       = "acme-prod"
    }
  }
}

variables {
  deployment = {
    name       = "hd"
    region     = "us-central1"
    host       = "helpdesk.example.com"
    xterm_host = "helpdesk-xterm.example.com"
    account_id = "acme-prod"
  }
  state    = { bucket = "duplo-helpdesk-tfstate-acme-prod", region = "us-central1", platform_key = "deployments/hd/platform" }
  storage  = { mode = "filestore", values = {}, provides = {} }
  helpdesk = { mode = "create", values = { local_admin_email = "admin@example.com" }, provides = {} }
  secrets  = { local_admin_password = "correct-horse-battery" }
}

run "storage_new_filestore" {
  command = apply

  assert {
    condition     = output.storage_class_name == "hd-gke-filestore"
    error_message = "New Filestore mode names the class after the deployment."
  }
  assert {
    condition     = yamldecode(module.helpdesk.values).fullnameOverride == "duplo-ai-helpdesk"
    error_message = "The chart's names are set explicitly, matching the chart's own rule for this release name."
  }
  assert {
    condition = yamldecode(module.helpdesk.values).filestore == {
      enabled      = true
      size         = "100Gi"
      storageClass = { create = false, name = "hd-gke-filestore" }
    }
    error_message = "The chart uses the class from modules/storage at the 100Gi default instead of creating its own."
  }
  assert {
    condition     = !can(yamldecode(module.helpdesk.values).backend.persistence.storageClass)
    error_message = "The chart refuses backend.persistence.storageClass together with filestore.enabled."
  }
  assert {
    condition     = yamldecode(module.helpdesk.values).duploAgent.persistence == { existingClaim = "duplo-ai-helpdesk-backend" }
    error_message = "The agent shares the backend's volume, so the chart creates one Filestore instance, not two."
  }
  assert {
    condition     = strcontains(module.helpdesk.release_name, "duplo-ai-helpdesk")
    error_message = "The Helpdesk release is installed."
  }
}

run "storage_new_filestore_size" {
  command = plan

  variables {
    storage  = { mode = "filestore", values = { filestore_size = "2Ti", filestore_tier = "zonal" }, provides = {} }
    helpdesk = { mode = "create", values = { local_admin_email = "admin@example.com", release_name = "acme" }, provides = {} }
  }

  assert {
    condition     = yamldecode(module.helpdesk.values).filestore.size == "2Ti"
    error_message = "The size option changes the Filestore size."
  }
  assert {
    condition     = yamldecode(module.helpdesk.values).duploAgent.persistence.existingClaim == "acme-helpdesk-backend"
    error_message = "The agent's claim follows the chart's fullname: <release>-helpdesk when the release name lacks it."
  }
}

run "rejects_filestore_size_below_100gi" {
  command = plan

  variables {
    storage = { mode = "filestore", values = { filestore_size = "50Gi" }, provides = {} }
  }

  expect_failures = [var.storage]
}

run "rejects_bad_filestore_size" {
  command = plan

  variables {
    storage = { mode = "filestore", values = { filestore_size = "100GB" }, provides = {} }
  }

  expect_failures = [var.storage]
}

run "storage_existing_filestore" {
  command = apply

  variables {
    storage = { mode = "existing", values = {}, provides = { filestore_id = "projects/acme-prod/locations/us-central1-a/instances/corp", filestore_ip = "10.9.0.2", filestore_share = "share1" } }
  }

  assert {
    condition     = module.storage.nfs_server == "10.9.0.2:/share1"
    error_message = "Existing Filestore mode serves the share through the NFS provisioner."
  }
  assert {
    condition     = yamldecode(module.helpdesk.values).backend.persistence.storageClass == "hd-gke-filestore" && !can(yamldecode(module.helpdesk.values).filestore)
    error_message = "The backend mounts the provisioner's class; the chart creates no Filestore."
  }
}

run "storage_in_cluster_nfs" {
  command = apply

  variables {
    storage = { mode = "incluster", values = { nfs_server_disk_size = "100Gi" }, provides = {} }
  }

  assert {
    condition     = module.storage.nfs_server == null
    error_message = "In-cluster NFS needs no provisioner; the chart runs the NFS server."
  }
  assert {
    condition     = yamldecode(module.helpdesk.values)["nfs-server"].persistence.size == "100Gi"
    error_message = "The NFS disk size reaches the Helpdesk release."
  }
  assert {
    condition     = yamldecode(module.helpdesk.values)["nfs-server"].storageClass.name == "hd-gke-nfs" && output.storage_class_name == "hd-gke-nfs"
    error_message = "The in-cluster NFS StorageClass is named per install, not a cluster-wide \"nfs\"."
  }
}

run "external_dns_lists_a_records" {
  command = apply

  assert {
    condition     = length(output.dns_records) == 2 && output.dns_records[0].type == "A" && output.dns_records[0].value == "34.120.0.10"
    error_message = "External DNS lists A records for both hostnames."
  }
  assert {
    condition     = output.load_balancer_hostname == "34.120.0.10"
    error_message = "The gateway IP is an output."
  }
  assert {
    condition     = length(module.helpdesk.a_record_names) == 0
    error_message = "External DNS creates no records."
  }
}

run "managed_dns_creates_a_records" {
  command = apply

  override_data {
    target = data.terraform_remote_state.platform
    values = {
      outputs = {
        cluster_endpoint     = "203.0.113.10"
        network_name         = "hd-vpc"
        certificate_map_name = "certmap-hd-helpdesk"
        dns_mode             = "managed"
        dns_zone_name        = "example-com"
        dns_zone_project     = "acme-prod"
      }
    }
  }

  assert {
    condition     = length(output.dns_records) == 0 && length(module.helpdesk.a_record_names) == 2
    error_message = "Managed DNS writes the A records itself and lists none."
  }
}

run "local_admin_signs_in" {
  command = plan

  assert {
    condition = (
      yamldecode(module.helpdesk.values).backend.extraEnv == [{ name = "Authentication__LocalAdminEmail", value = "admin@example.com" }]
      && yamldecode(module.helpdesk.values).config.authSuperUsers == "admin@example.com"
      && !can(yamldecode(module.helpdesk.values).secrets)
    )
    error_message = "The local admin is the only sign-in: no Google or Microsoft client IDs in the values."
  }
}

run "generated_and_secret_outputs" {
  command = apply

  assert {
    condition     = length(nonsensitive(output.generated.jwt_shared_secret)) > 0 && nonsensitive(output.secrets.local_admin_password) == "correct-horse-battery"
    error_message = "Takeover can read the generated and passed-in secrets."
  }
}

run "plans_without_platform_outputs" {
  command = plan

  override_data {
    target = data.terraform_remote_state.platform
    values = { outputs = {} }
  }
}

run "ignores_a_saved_login_method" {
  command = plan

  variables {
    helpdesk = { mode = "create", values = { login_method = "google", local_admin_email = "admin@example.com" }, provides = {} }
  }

  assert {
    condition     = yamldecode(module.helpdesk.values).config.authSuperUsers == "admin@example.com"
    error_message = "A login_method saved by an older release is ignored; the local admin signs in."
  }
}

run "rejects_missing_admin_email" {
  command = plan

  variables {
    helpdesk = { mode = "create", values = {}, provides = {} }
  }

  expect_failures = [var.helpdesk]
}

run "local_login_requires_password" {
  command = plan

  variables {
    secrets = {}
  }

  expect_failures = [var.secrets]
}

run "long_prefix_keeps_service_account_ids_within_30" {
  command = apply

  override_data {
    target = data.terraform_remote_state.platform
    values = { outputs = { name_prefix = "a-very-long-deployment-name-32ch-gke", cluster_endpoint = "203.0.113.10", dns_mode = "external" } }
  }

  assert {
    condition     = alltrue([for k, id in module.helpdesk.service_account_ids : length(id) <= 30 && endswith(id, k)])
    error_message = "Service account ids keep their purpose and stay within GCP's 30 characters."
  }
}

run "custom_namespace" {
  command = apply

  variables {
    helpdesk = { mode = "create", values = { local_admin_email = "admin@example.com", namespace = "support-desk" }, provides = {} }
  }

  assert {
    condition     = module.helpdesk.namespace == "support-desk" && output.release.namespace == "support-desk" && output.release.name == "duplo-ai-helpdesk"
    error_message = "The Helm release goes into the chosen namespace."
  }
}

run "rejects_bad_namespace" {
  command = plan

  variables {
    helpdesk = { mode = "create", values = { local_admin_email = "admin@example.com", namespace = "Support_Desk" }, provides = {} }
  }

  expect_failures = [var.helpdesk]
}

run "rejects_bad_storage_mode" {
  command = plan

  variables {
    storage = { mode = "create", values = {}, provides = {} }
  }

  expect_failures = [var.storage]
}

run "values_match_aws" {
  command = plan

  assert {
    condition = (
      yamldecode(module.helpdesk.values).xterm.enabled == true
      && yamldecode(module.helpdesk.values).config.mongoDbDatabaseName == "duplo-ai-helpdesk"
      && yamldecode(module.helpdesk.values).config.aiStudioIsMasterDisabled == true
      && yamldecode(module.helpdesk.values).mongodb.backup.enabled == false
    )
    error_message = "As on AWS: the web terminal runs, the database name is fixed, and the MongoDB sub-chart backup is off."
  }
  assert {
    condition     = !can(yamldecode(module.helpdesk.values).mongodbBackup)
    error_message = "The chart's MongoDB dump keeps its own claim on the default Persistent Disk class (no Filestore instance, nothing orphaned on upgrade)."
  }
  assert {
    condition     = yamldecode(module.helpdesk.values).slackBackend == { enabled = false }
    error_message = "Slack is off by default."
  }
}

run "slack_backend" {
  command = plan

  variables {
    helpdesk = { mode = "create", values = {
      local_admin_email                = "admin@example.com"
      slack_backend_enabled            = true
      slack_backend_image_tag          = "1.2.3"
      slack_helpdesk_default_agent     = "support"
      slack_helpdesk_default_workspace = "acme"
      slack_app_portals                = "[{\"portal\":\"acme\"}]"
    }, provides = {} }
    secrets = { local_admin_password = "correct-horse-battery", slack_app_token = "xapp-test", slack_bot_token = "xoxb-test" }
  }

  assert {
    condition = (
      yamldecode(module.helpdesk.values).slackBackend.enabled == true
      && yamldecode(module.helpdesk.values).slackBackend.image.tag == "1.2.3"
      && yamldecode(module.helpdesk.values).slackBackend.env == { helpdeskDefaultAgent = "support", helpdeskDefaultWorkspace = "acme" }
      && yamldecode(module.helpdesk.values).slackBackend.envFromSecret.data.DUPLO_SLACK_APP_PORTALS == "[{\"portal\":\"acme\"}]"
    )
    error_message = "Enabling Slack renders the Slack backend as on AWS."
  }
  assert {
    condition     = !strcontains(module.helpdesk.values, "xoxb-test") && !strcontains(module.helpdesk.values, "xapp-test")
    error_message = "The Slack tokens never appear in the values document; they go through set_sensitive."
  }
}

run "adopted_bucket_without_arn" {
  command = plan

  override_data {
    target = data.terraform_remote_state.platform
    values = {
      outputs = {
        cluster_endpoint       = "203.0.113.10"
        cluster_ca_certificate = "Q0E="
        network_name           = "hd-vpc"
        bucket_name            = "corp-data"
        bucket_arn             = null
        userdata_bucket_name   = ""
        userdata_bucket_arn    = ""
        certificate_map_name   = "certmap-hd-helpdesk"
        dns_mode               = "external"
      }
    }
  }

  assert {
    condition     = strcontains(module.helpdesk.release_name, "duplo-ai-helpdesk")
    error_message = "The app root plans with adopted buckets that have no ARN and no user data bucket."
  }
}

run "dns_records_empty_until_lb_known" {
  command = apply

  override_resource {
    target = module.helpdesk.google_compute_global_address.gateway
    values = { address = "" }
  }

  assert {
    condition     = output.load_balancer_hostname == "" && length(output.dns_records) == 0
    error_message = "dns_records must be empty until the Gateway IP is known."
  }
}

run "backend_impersonation_accepts_service_account_emails" {
  command = plan

  variables {
    helpdesk = { mode = "create", values = { local_admin_email = "admin@example.com", backend_impersonate_service_accounts = [
      "helpdesk-reader@acme-prod.iam.gserviceaccount.com",
      "123456789012-compute@developer.gserviceaccount.com",
      "acme-prod@appspot.gserviceaccount.com",
    ] }, provides = {} }
  }
}

run "backend_impersonation_rejects_other_text" {
  command = plan

  variables {
    helpdesk = { mode = "create", values = { local_admin_email = "admin@example.com", backend_impersonate_service_accounts = ["projects/acme-prod/serviceAccounts/x"] }, provides = {} }
  }

  expect_failures = [var.helpdesk]
}

run "backend_impersonation_rejects_a_bare_domain" {
  command = plan

  variables {
    helpdesk = { mode = "create", values = { local_admin_email = "admin@example.com", backend_impersonate_service_accounts = ["reader@gserviceaccount.com"] }, provides = {} }
  }

  expect_failures = [var.helpdesk]
}
