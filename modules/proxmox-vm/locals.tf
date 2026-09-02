locals {
  # PVE attributes
  vm_name          = var.vm_name != "" ? var.vm_name : "vm-${var.vm_id}"
  pve_node         = var.node
  iso_storage_pool = var.iso_storage_pool

  # Whether to set a password at all — true if either a plaintext password was
  # directly provided OR the auto-generate flag is enabled.
  should_set_user_password = var.cloudinit.user_password != null || var.cloudinit.set_user_password
  should_set_root_password = var.cloudinit.root_password != null || var.cloudinit.set_root_password

  # The plaintext to hash: provided password takes precedence over auto-generated.
  plaintext_user_password = var.cloudinit.user_password != null ? var.cloudinit.user_password : (var.cloudinit.set_user_password ? random_password.user_password[0].result : "")
  plaintext_root_password = var.cloudinit.root_password != null ? var.cloudinit.root_password : (var.cloudinit.set_root_password ? random_password.root_password[0].result : "")

  # Hash the user password — read from terraform_data to avoid bcrypt() being
  # re-evaluated on every plan (bcrypt is non-deterministic; see main.tf).
  root_password_hash = local.should_set_root_password ? terraform_data.root_password_hash[0].output : ""
  user_password_hash = local.should_set_user_password ? terraform_data.user_password_hash[0].output : ""

  # SSH connection
  generated_ssh_key = var.generate_ssh_key ? [trimspace(tls_private_key.ssh_key[0].public_key_openssh)] : []
  combined_ssh_keys = concat(var.ssh_keys, local.generated_ssh_key)

  # ============================================================
  #  IP Address Calculation
  # ============================================================

  # Parse the provided IP address (e.g., "192.168.1.130/24")
  ip_cidr_split = split("/", var.cloudinit.ip_address)
  ip_address    = local.ip_cidr_split[0]
  cidr_suffix   = length(local.ip_cidr_split) > 1 ? local.ip_cidr_split[1] : "24"
  ip_parts      = split(".", local.ip_address)

  # Generate list of IPs by incrementing the last octet
  generated_ips = [
    for i in range(var.vm_count) :
    format("%s.%s.%s.%d/%s",
      local.ip_parts[0],
      local.ip_parts[1],
      local.ip_parts[2],
      tonumber(local.ip_parts[3]) + i,
      local.cidr_suffix
    )
  ]
}
