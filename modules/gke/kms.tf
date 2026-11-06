data "google_project" "this" {
  project_id = var.project_id
}

resource "google_kms_crypto_key_iam_member" "cmek" {
  count = var.cmek_key != "" ? 1 : 0

  crypto_key_id = var.cmek_key
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.this.number}@container-engine-robot.iam.gserviceaccount.com"
}
