# The RWX storage Helpdesk mounts:
#   filestore: the Filestore StorageClass (Basic HDD) here; the Helpdesk chart uses it (filestore.storageClass.create
#              false) and the GKE Filestore CSI driver creates one instance when the backend volume binds
#   existing:  volumes are subdirectories of an existing Filestore share, served by an NFS provisioner
#   incluster: nothing here; the Helpdesk chart runs its own NFS server
locals {
  csi      = var.mode == "filestore"
  existing = var.mode == "existing"
}

# Owned here rather than by the chart, which keeps its class on uninstall (helm.sh/resource-policy: keep): a destroy
# deletes the class. Retain still keeps the Filestore instance (and Helpdesk's data); it keeps billing until deleted.
# Parameters are immutable, so a change (e.g. an earlier release's zonal class, or a new VPC) replaces the class;
# volumes already bound keep their instance.
resource "kubernetes_storage_class_v1" "filestore" {
  count = local.csi ? 1 : 0

  metadata {
    name = var.storage_class_name
  }

  storage_provisioner    = "filestore.csi.storage.gke.io"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    tier = "standard" # Basic HDD, the only tier offered
    # The VPC has no Private Service Access connection, which the chart's default connect mode needs.
    network        = var.network_name
    "connect-mode" = "DIRECT_PEERING"
    # The CSI driver puts these labels on the instance, so it can be found after a destroy (filestore_cleanup).
    labels = "duplocloud-deployment=${var.deployment_name},duplocloud-managed-by=cloud-deployment-agent"
  }
}

resource "kubernetes_namespace_v1" "nfs" {
  count = local.existing ? 1 : 0

  metadata {
    name = var.nfs_provisioner_namespace
  }

  lifecycle {
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

resource "helm_release" "nfs_provisioner" {
  count = local.existing ? 1 : 0

  name       = "nfs-subdir-external-provisioner"
  repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart      = "nfs-subdir-external-provisioner"
  version    = var.nfs_provisioner_chart_version
  namespace  = kubernetes_namespace_v1.nfs[0].metadata[0].name

  set = [
    { name = "nfs.server", value = var.filestore_ip },
    { name = "nfs.path", value = "/${var.filestore_share}" },
    { name = "storageClass.name", value = var.storage_class_name },
    { name = "storageClass.reclaimPolicy", value = "Retain" },
    { name = "storageClass.archiveOnDelete", value = "true" },
    { name = "storageClass.pathPattern", value = "$${.PVC.namespace}/$${.PVC.name}" },
  ]
}
