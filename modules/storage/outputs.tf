output "storage_class_name" {
  description = "RWX storage class Helpdesk mounts"
  value       = var.storage_class_name
}

output "helpdesk_storage" {
  description = "The storage input of modules/helpdesk: mode, StorageClass and the mode's settings"
  value = {
    mode                 = var.mode
    class_name           = var.storage_class_name
    filestore_size       = var.filestore_size
    nfs_server_disk_size = var.nfs_server_disk_size
  }
}

output "nfs_server" {
  description = "NFS export the provisioner serves (null unless existing mode)"
  value       = local.existing ? "${var.filestore_ip}:/${var.filestore_share}" : null
}
