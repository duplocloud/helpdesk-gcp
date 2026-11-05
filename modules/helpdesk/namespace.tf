# PSS baseline audit/warn only: xterm and duplo-agent need privileges.
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}
