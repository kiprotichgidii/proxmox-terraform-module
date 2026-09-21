locals {
  # PVE attributes
  vm_name          = var.vm_name != "" ? var.vm_name : "vm-${var.vm_id}"
  pve_node         = var.node
  iso_storage_pool = var.iso_storage_pool

  # SSH host for snippet uploads — parse from API URL when not explicitly set.
  # e.g. "https://192.168.1.3:8006/api2/json" → "192.168.1.3"
  pve_ssh_host = var.proxmox_node_host != "" ? var.proxmox_node_host : regex("https?://([^:/]+)", var.proxmox_api_url)[0]

  # ============================================================
  # Snippet file names (one set per VM instance)
  # ============================================================
  snippet_user_data_files = [for i in range(var.vm_count) : "${local.vm_name}-${i + 1}-user.yaml"]
  snippet_network_files   = [for i in range(var.vm_count) : "${local.vm_name}-${i + 1}-network.yaml"]
  snippet_meta_files      = [for i in range(var.vm_count) : "${local.vm_name}-${i + 1}-meta.yaml"]

  # ============================================================
  # Password logic
  # ============================================================

  # Whether to set a password at all — true if either a plaintext password was
  # directly provided OR the auto-generate flag is enabled.
  should_set_user_password = var.cloudinit.user_password != null || var.cloudinit.set_user_password
  should_set_root_password = var.cloudinit.root_password != null || var.cloudinit.set_root_password

  # The plaintext to hash: provided password takes precedence over auto-generated.
  plaintext_user_password = var.cloudinit.user_password != null ? var.cloudinit.user_password : (var.cloudinit.set_user_password ? random_password.user_password[0].result : "")
  plaintext_root_password = var.cloudinit.root_password != null ? var.cloudinit.root_password : (var.cloudinit.set_root_password ? random_password.root_password[0].result : "")

  # Hash the user password — read from terraform_data to avoid bcrypt() being
  # re-evaluated on every plan/apply (bcrypt is non-deterministic; see main.tf).
  root_password_hash = local.should_set_root_password ? terraform_data.root_password_hash[0].output : ""
  user_password_hash = local.should_set_user_password ? terraform_data.user_password_hash[0].output : ""

  # SSH connection
  generated_ssh_key = var.generate_ssh_key ? [trimspace(tls_private_key.ssh_key[0].public_key_openssh)] : []
  combined_ssh_keys = concat(var.ssh_keys, local.generated_ssh_key)

  # ============================================================
  # IP Address Calculation
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

  # ============================================================
  # Pre-rendered cloud-init templates (one per VM instance)
  # Computed here so they can be used in both null_resource
  # triggers (for change detection) and file provisioner content.
  # ============================================================

  rendered_user_data = [
    for i in range(var.vm_count) :
    templatefile("${path.module}/cloudinit-templates/user_data.tpl", {
      timezone                 = var.cloudinit.timezone
      manage_etc_hosts         = var.cloudinit.manage_etc_hosts
      preserve_hostname        = var.cloudinit.preserve_hostname
      enable_ssh_password_auth = var.cloudinit.enable_ssh_password_auth
      disable_ssh_root_login   = var.cloudinit.disable_ssh_root_login
      lock_root_user_password  = var.cloudinit.lock_root_user_password
      set_root_password        = local.should_set_root_password
      root_password            = local.root_password_hash
      user_name                = var.cloudinit.user_name
      user_fullname            = var.cloudinit.user_fullname
      user_shell               = var.cloudinit.user_shell
      user_password            = local.user_password_hash
      set_user_password        = local.should_set_user_password
      lock_user_password       = var.cloudinit.lock_user_password
      set_any_password         = local.should_set_user_password || local.should_set_root_password
      authorized_keys          = local.combined_ssh_keys
      disable_ipv6             = var.cloudinit.disable_ipv6
      package_update           = var.cloudinit.package_update
      package_upgrade          = var.cloudinit.package_upgrade
      packages                 = var.cloudinit.packages
      runcmds                  = var.cloudinit.runcmds
    })
  ]

  rendered_network_config = [
    for i in range(var.vm_count) :
    templatefile("${path.module}/cloudinit-templates/network_config.tpl", {
      enable_dhcp = var.cloudinit.enable_dhcp
      ip_address  = local.generated_ips[i]
      nic         = var.cloudinit.nic
      gateway     = var.cloudinit.gateway
      dns_servers = var.cloudinit.dns_servers
    })
  ]

  rendered_meta_data = [
    for i in range(var.vm_count) :
    templatefile("${path.module}/cloudinit-templates/meta_data.tpl", {
      instance_id = sha1(local.vm_name)
      hostname    = var.cloudinit.hostname != "" ? var.cloudinit.hostname : "${local.vm_name}-${i + 1}"
    })
  ]
}
