locals {
  # PVE attributes
  vm_name          = var.vm_name != "" ? var.vm_name : "vm-${var.vm_id}"
  pve_node         = var.node
  iso_storage_pool = var.iso_storage_pool

  # Hash the user password
  root_password_hash = var.cloudinit.set_root_password ? bcrypt(random_password.root_password[0].result) : ""
  user_password_hash = var.cloudinit.set_user_password ? bcrypt(random_password.user_password[0].result) : ""

  # SSH connection
  generated_ssh_key = var.generate_ssh_key ? [trimspace(tls_private_key.ssh_key[0].public_key_openssh)] : []
  combined_ssh_keys = concat(var.ssh_keys, local.generated_ssh_key)
}