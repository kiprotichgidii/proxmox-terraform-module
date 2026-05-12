# Terraform Provider Versions
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "= 3.0.2-rc06"
    }
  }
}

# Proxmox VM Resource
module "proxmox_vm" {
  #source = "./modules/proxmox-vm"
  source = "git::https://github.com/kiprotichgidii/proxmox-terraform-module.git//modules/proxmox-vm?ref=main"
  # provider Variables
  proxmox_api_url  = var.proxmox_api_url
  #proxmox_user     = var.proxmox_user
  #proxmox_password = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  # Qemu VM variables
  vm_count    = 1
  vm_name     = "ubuntu-resolute"
  node        = "pve02"
  cpu_cores   = 2
  cpu_sockets = 1
  memory      = 4096
  boot_order  = "order=scsi0;ide2;net0"
  #bios             = "ovmf"
  template_id      = 8805
  clone            = true
  storage_pool     = "zfs-pool"
  iso_storage_pool = "local"
  disks = [
    {
      size    = "50G"
      storage = "zfs-pool"
      type    = "disk"
      slot    = "scsi0"
      format  = "qcow2"
    }
  ]
  networks = [
    {
      id     = "0"
      bridge = "vmbr0"
      model  = "virtio"
    }
  ]
  cloudinit = {
    user_fullname = "Gedion Kiprotich"
    timezone      = "Africa/Nairobi"
    #ip_address    = "192.168.1.140/24"
    #enable_dhcp   = false
    #nic           = "enp6s18"
  }

}

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
