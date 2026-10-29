# PSS baseline audit/warn only: xterm and duplo-agent need privileges.
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      "pod-security.kubernetes.io/audit"   = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}
