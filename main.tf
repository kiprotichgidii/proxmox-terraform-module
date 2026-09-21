# ============================================================
# Terraform / Provider Requirements
# ============================================================

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "= 3.0.2-rc06"
    }
  }
}

# ============================================================
# Proxmox VM Module
# ============================================================

module "proxmox_vm" {
  source = "./modules/proxmox-vm"
  #source = "git::https://github.com/kiprotichgidii/proxmox-terraform-module.git//modules/proxmox-vm?ref=main"

  # --- Provider ---
  proxmox_api_url          = var.proxmox_api_url
  proxmox_user             = var.proxmox_user
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret

  # --- SSH ---
  ssh_keys         = var.ssh_keys
  generate_ssh_key = var.generate_ssh_key

  # --- QEMU / VM ---
  vm_name          = var.vm_name
  node             = var.node
  cpu_cores        = var.cpu_cores
  cpu_sockets      = var.cpu_sockets
  memory           = var.memory
  bios             = var.bios
  boot_order       = var.boot_order
  template_id      = var.template_id
  clone            = var.clone
  storage_pool     = var.storage_pool
  iso_storage_pool = var.iso_storage_pool

  # --- Disks ---
  disks = var.disks

  # --- Networks ---
  networks = var.networks

  # --- Cloud-Init ---
  cloudinit = var.cloudinit
}

# ============================================================
# Outputs
# ============================================================

output "vm_id" {
  value = module.proxmox_vm.vmid
}

output "vm_name" {
  value = module.proxmox_vm.name
}

output "ssh_user_name" {
  value = module.proxmox_vm.ssh_user
}

output "vm_ip_addresses" {
  value = module.proxmox_vm.vm_ip_addresses
}

output "ssh_commands" {
  value = module.proxmox_vm.ssh_commands
}
