#----------------------------------------------------------
# Random Resource Creation
#----------------------------------------------------------
resource "random_password" "root_password" {
  count            = var.cloudinit.set_root_password ? 1 : 0
  length           = 8
  special          = true
  override_special = "_%@"
}

resource "random_password" "user_password" {
  count            = var.cloudinit.set_user_password ? 1 : 0
  length           = 8
  special          = true
  override_special = "_%@"
}

resource "tls_private_key" "ssh_key" {
  count     = var.generate_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ============================================================
#  File Creation
# ============================================================
resource "local_sensitive_file" "root_password" {
  count           = var.cloudinit.set_root_password ? 1 : 0
  content         = random_password.root_password[count.index].result
  filename        = "${path.cwd}/root_password.txt"
  file_permission = "0600"
}

resource "local_sensitive_file" "user_password" {
  count           = var.cloudinit.set_user_password ? 1 : 0
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
data "template_cloudinit_config" "cloudinit" {
  count         = var.vm_count
  gzip          = false
  base64_encode = false

  part {
    filename     = "user-data"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloudinit-templates/user_data.tpl", {
      timezone                 = var.cloudinit.timezone
      manage_etc_hosts         = var.cloudinit.manage_etc_hosts
      preserve_hostname        = var.cloudinit.preserve_hostname
      enable_ssh_password_auth = var.cloudinit.enable_ssh_password_auth
      disable_ssh_root_login   = var.cloudinit.disable_ssh_root_login
      lock_root_user_password  = var.cloudinit.lock_root_user_password
      set_root_password        = var.cloudinit.set_root_password
      root_password            = local.root_password_hash
      user_name                = var.cloudinit.user_name
      user_fullname            = var.cloudinit.ssh_user_fullname
      user_shell               = var.cloudinit.ssh_user_shell
      user_password            = local.user_password_hash
      set_user_password        = var.cloudinit.set_user_password
      lock_user_password       = var.cloudinit.lock_user_password
      authorized_keys          = local.combined_ssh_keys
      disable_ipv6             = var.cloudinit.disable_ipv6
      package_update           = var.cloudinit.package_update
      package_upgrade          = var.cloudinit.package_upgrade
      packages                 = var.cloudinit.packages
      runcmds                  = var.cloudinit.runcmds
    })
  }

  part {
    filename     = "meta-data"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/templates/cloud-init/meta_data.tpl", {
      instance_id    = sha1(local.vm_name)
      local_hostname = var.cloudinit.hostname != "" ? var.cloudinit.hostname : local.vm_name
    })
  }

  part {
    filename     = "network-config"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloudinit-templates/network_config.tpl", {
      enable_dhcp = var.cloudinit.enable_dhcp
      ip_address  = var.cloudinit.ip_address
      gateway     = var.cloudinit.gateway
      dns_servers = var.cloudinit.dns_servers
    })
  }
}
resource "proxmox_cloud_init_disk" "cloudinit_ci" {
  count          = var.vm_count
  name           = "${local.vm_name}-cloudinit-${count.index}.iso"
  pve_node       = local.pve_node
  storage        = local.iso_storage_pool
  user_date      = data.template_cloudinit_config.cloudinit[count.index].rendered
  meta_data      = data.template_cloudinit_config.cloudinit[count.index].part[1].content
  network_config = data.template_cloudinit_config.cloudinit[count.index].part[2].content
}

# ============================================================
#  Create the Virtual Machine
# ============================================================
resource "proxmox_vm_qemu" "qemu_vm" {
  count       = var.vm_count
  vmid        = var.vm_id + count.index
  name        = "${local.vm_name}-${count.index}"
  target_node = local.pve_node
  cores       = var.cpu_cores
  sockets     = var.cpu_sockets
  memory      = var.memory
  boot        = var.boot_order
  bios        = var.bios
  machine     = var.machine_type
  onboot      = var.onboot
  agent       = var.guest_agent
  clone       = var.template_id
  scsihw      = var.scsi_hardware
  vm_state    = var.vm_state

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
  # Define a disk block with media type cdrom which references the generated cloud-init disk
  disk {
    type    = "ide"
    media   = "cdrom"
    slot    = "ide2"
    storage = local.iso_storage_pool
    volume  = proxmox_cloud_init_disk.cloudinit_ci.id
    size    = proxmox_cloud_init_disk.cloudinit_ci.size
  }

  serial {
    id   = 0
    type = "socket"
  }

  dynamic "network" {
    for_each = var.networks
    content {
      model    = network.value.model
      bridge   = network.value.bridge
      macaddr  = lookup(network.value, "macaddr", null)
      firewall = lookup(network.value, "firewall", false)
    }
  }

  lifecycle {
    postcondition {
      condition = length(self.network) > 0
      error_message = "Guest agent did not return network info yet."
    }
  }

  depends_on = [proxmox_cloud_init_disk.cloudinit_ci]
}
