#============================================================
# Random Resource Creation
#============================================================

# Only auto-generate if no plaintext password was directly provided.
resource "random_password" "root_password" {
  count            = var.cloudinit.set_root_password && var.cloudinit.root_password == null ? 1 : 0
  length           = 8
  special          = true
  override_special = "_%@"
}

resource "random_password" "user_password" {
  count            = var.cloudinit.set_user_password && var.cloudinit.user_password == null ? 1 : 0
  length           = 8
  special          = true
  override_special = "_%@"
}

# bcrypt() in Terraform is non-deterministic — it generates a new salt on every
# plan/apply, which means the hash in the cloud-init ISO would change on every
# run, invalidating the plaintext. terraform_data stores the hash in state so it
# is computed exactly once and only re-hashes when the source password changes.
resource "terraform_data" "user_password_hash" {
  count = local.should_set_user_password ? 1 : 0

  # Re-hash only when the plaintext source changes.
  triggers_replace = [local.plaintext_user_password]

  input = bcrypt(local.plaintext_user_password)
}

resource "terraform_data" "root_password_hash" {
  count = local.should_set_root_password ? 1 : 0

  triggers_replace = [local.plaintext_root_password]

  input = bcrypt(local.plaintext_root_password)
}

resource "tls_private_key" "ssh_key" {
  count     = var.generate_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ============================================================
#  File Creation
# ============================================================

# Only write password files for auto-generated passwords — the user already
# knows a plaintext password they provided themselves.
resource "local_sensitive_file" "root_password" {
  count           = var.cloudinit.set_root_password && var.cloudinit.root_password == null ? 1 : 0
  content         = random_password.root_password[count.index].result
  filename        = "${path.cwd}/root_password.txt"
  file_permission = "0600"
}

resource "local_sensitive_file" "user_password" {
  count           = var.cloudinit.set_user_password && var.cloudinit.user_password == null ? 1 : 0
  content         = random_password.user_password[count.index].result
  filename        = "${path.cwd}/user_password.txt"
  file_permission = "0600"
}

resource "local_sensitive_file" "ssh_private_key" {
  count           = var.generate_ssh_key ? 1 : 0
  content         = tls_private_key.ssh_key[count.index].private_key_pem
  filename        = "${path.cwd}/id_rsa.key"
  file_permission = "0600"
}

resource "local_sensitive_file" "ssh_public_key" {
  count           = var.generate_ssh_key ? 1 : 0
  content         = tls_private_key.ssh_key[count.index].public_key_openssh
  filename        = "${path.cwd}/id_rsa.pub"
  file_permission = "0644"
}

# ============================================================
#  Generate Cloudinit ISO
# ============================================================
resource "proxmox_cloud_init_disk" "cloudinit_ci" {
  count    = var.vm_count
  name     = "${var.vm_name}-cloudinit-${count.index + 1}"
  pve_node = local.pve_node
  storage  = local.iso_storage_pool
  #===========================================================
  # user_data template
  #===========================================================
  user_data = templatefile("${path.module}/cloudinit-templates/user_data.tpl", {
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
  #===========================================================
  # meta_data template
  #===========================================================
  meta_data = templatefile("${path.module}/cloudinit-templates/meta_data.tpl", {
    instance_id = sha1(local.vm_name)
    hostname    = var.cloudinit.hostname != "" ? var.cloudinit.hostname : "${local.vm_name}-${count.index + 1}"
  })
  #===========================================================
  # network_config template
  #===========================================================
  network_config = templatefile("${path.module}/cloudinit-templates/network_config.tpl", {
    enable_dhcp = var.cloudinit.enable_dhcp
    ip_address  = local.generated_ips[count.index]
    nic         = var.cloudinit.nic
    gateway     = var.cloudinit.gateway
    dns_servers = var.cloudinit.dns_servers
  })
}

# ============================================================
#  Create the Virtual Machine
# ============================================================
resource "proxmox_vm_qemu" "qemu_vm" {
  count       = var.vm_count
  vmid        = var.vm_id == 0 ? null : var.vm_id + count.index
  name        = "${local.vm_name}-${count.index + 1}"
  target_node = local.pve_node
  cpu {
    cores   = var.cpu_cores
    sockets = var.cpu_sockets
  }
  memory             = var.memory
  boot               = var.boot_order
  bios               = var.bios
  machine            = var.machine_type
  start_at_node_boot = var.autostart
  agent              = var.qemu_agent
  agent_timeout      = var.agent_timeout
  clone_id           = var.template_id
  scsihw             = var.scsi_hardware
  vm_state           = var.vm_state
  skip_ipv6          = var.skip_ipv6

  # Disk Configuration
  dynamic "disk" {
    for_each = var.disks
    content {
      size    = disk.value.size
      storage = disk.value.storage
      type    = disk.value.type
      slot    = disk.value.slot
      cache   = lookup(disk.value, "cache", "writeback")
      format  = lookup(disk.value, "format", "qcow2")
      discard = lookup(disk.value, "discard", true)
    }
  }
  # Define a disk block for the generated cloud-init disk
  disk {
    type = "cdrom"
    slot = "ide2"
    iso  = proxmox_cloud_init_disk.cloudinit_ci[count.index].id
  }
  # EFI disk for UEFI Boot
  dynamic "efidisk" {
    for_each = var.bios == "ovmf" ? [1] : []
    content {
      efitype = "4m"
      storage = var.storage_pool
    }
  }
  # Serial Console
  serial {
    id   = 0
    type = "socket"
  }
  # Network Configuration
  dynamic "network" {
    for_each = var.networks
    content {
      id       = network.value.id
      model    = network.value.model
      bridge   = network.value.bridge
      tag      = network.value.tag
      macaddr  = lookup(network.value, "macaddr", null)
      firewall = lookup(network.value, "firewall", false)
    }
  }
  # Lifecycle
  lifecycle {
    postcondition {
      condition     = length(self.network) > 0
      error_message = "Guest agent did not return network info yet."
    }
  }

  depends_on = [proxmox_cloud_init_disk.cloudinit_ci]
}

#============================================================
# The End
#============================================================
