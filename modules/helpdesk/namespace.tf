resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }

  # As on AWS: labels and annotations that other tools (Pod Security admission, policy agents) add are left alone.
  lifecycle {
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}
