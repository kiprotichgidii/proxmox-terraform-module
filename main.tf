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
  proxmox_api_url = var.proxmox_api_url
  proxmox_user    = var.proxmox_user
  #proxmox_password = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  ssh_keys                 = var.ssh_keys
  generate_ssh_key         = false
  # Qemu VM variables
  vm_count         = 2
  vm_name          = "AlmaLinux-8"
  node             = "proxmox-pve01"
  cpu_cores        = 2
  cpu_sockets      = 1
  memory           = 4096
  bios             = "ovmf"
  boot_order       = "order=scsi0;ide2"
  template_id      = 9024
  clone            = true
  storage_pool     = "nvme-storage"
  iso_storage_pool = "local"
  disks = [
    {
      size    = "50G"
      storage = "nvme-storage"
      type    = "disk"
      slot    = "scsi0"
      format  = "qcow2"
    }
  ]
  networks = [
    {
      id     = "10"
      bridge = "vmbr0"
      model  = "virtio"
      tag    = "30"
    }
  ]
  cloudinit = {
    user_fullname = "Gedion Kiprotich"
    timezone      = "Africa/Nairobi"
    #ip_address        = "172.20.30.10/24"
    #gateway           = "172.20.30.1"
    enable_dhcp = true
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
