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
#  Upload Cloud-Init Snippets to Proxmox via SSH
#
#  Proxmox's Cloud-Init tab only recognises a drive registered
#  as type "cloudinit" (set via cloudinit_cdrom_storage below).
#  cicustom then points Proxmox at our custom YAML files so we
#  keep full template control while the UI tab works correctly.
#
#  Pre-requisite: enable the Snippets content type on the
#  target storage pool in the Proxmox UI or via:
#    pvesm set local --content images,rootdir,vztmpl,iso,backup,snippets
# ============================================================

# Upload rendered cloud-init snippets to the Proxmox node.
# Runs on create; re-runs whenever rendered content changes.
resource "null_resource" "upload_cloudinit" {
  count = var.vm_count

  triggers = {
    user_data_content      = local.rendered_user_data[count.index]
    network_config_content = local.rendered_network_config[count.index]
    meta_data_content      = local.rendered_meta_data[count.index]
    user_data_file         = local.snippet_user_data_files[count.index]
    network_config_file    = local.snippet_network_files[count.index]
    meta_data_file         = local.snippet_meta_files[count.index]
    snippets_path          = var.snippets_storage_path
  }

  connection {
    type        = "ssh"
    host        = local.pve_ssh_host
    user        = var.proxmox_ssh_user
    private_key = var.proxmox_ssh_private_key
  }

  provisioner "file" {
    content     = self.triggers.user_data_content
    destination = "${self.triggers.snippets_path}/${self.triggers.user_data_file}"
  }

  provisioner "file" {
    content     = self.triggers.network_config_content
    destination = "${self.triggers.snippets_path}/${self.triggers.network_config_file}"
  }

  provisioner "file" {
    content     = self.triggers.meta_data_content
    destination = "${self.triggers.snippets_path}/${self.triggers.meta_data_file}"
  }
}

# Remove snippet files from Proxmox when the VM is destroyed.
# Kept as a separate resource so its connection block can reference
# only self.triggers (destroy-time provisioner restriction in OpenTofu).
resource "null_resource" "cleanup_cloudinit" {
  count = var.vm_count

  # Mirror the same triggers so cleanup fires whenever upload fires.
  triggers = {
    user_data_file      = local.snippet_user_data_files[count.index]
    network_config_file = local.snippet_network_files[count.index]
    meta_data_file      = local.snippet_meta_files[count.index]
    snippets_path       = var.snippets_storage_path
    pve_ssh_host        = local.pve_ssh_host
    ssh_user            = var.proxmox_ssh_user
    # Store the key in triggers so it's accessible during destroy.
    # Marked sensitive in the variable declaration.
    ssh_private_key     = var.proxmox_ssh_private_key
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "rm -f ${self.triggers.snippets_path}/${self.triggers.user_data_file}",
      "rm -f ${self.triggers.snippets_path}/${self.triggers.network_config_file}",
      "rm -f ${self.triggers.snippets_path}/${self.triggers.meta_data_file}",
    ]
    connection {
      type        = "ssh"
      host        = self.triggers.pve_ssh_host
      user        = self.triggers.ssh_user
      private_key = self.triggers.ssh_private_key
    }
  }

  depends_on = [null_resource.upload_cloudinit]
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

  # Use Proxmox's native cloud-init drive so the Cloud-Init tab is visible in the UI.
  # cicustom overrides the drive content with our custom rendered snippets.
  cicustom = join(",", [
    "user=${var.snippets_storage}:snippets/${local.snippet_user_data_files[count.index]}",
    "network=${var.snippets_storage}:snippets/${local.snippet_network_files[count.index]}",
    "meta=${var.snippets_storage}:snippets/${local.snippet_meta_files[count.index]}",
  ])

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

  # Native Proxmox cloud-init drive — makes the Cloud-Init tab visible in the UI
  disk {
    type    = "cloudinit"
    slot    = "ide2"
    storage = var.snippets_storage
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

  # Snippets must exist on the Proxmox node before the VM is created
  depends_on = [null_resource.upload_cloudinit, null_resource.cleanup_cloudinit]
}

#============================================================
# The End
#============================================================
