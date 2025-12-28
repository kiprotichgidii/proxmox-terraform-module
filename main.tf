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
  source = "./modules/proxmox-vm"
  #source = "git::https://github.com/kiprotichgidii/proxmox-terraform-module.git//modules/proxmox-vm?ref=main"
  # provider Variables
  proxmox_api_url  = "https://192.168.1.2:8006/api2/json"
  proxmox_user     = "terraform@pve"
  proxmox_password = "Xcqt0689"
  #proxmox_api_token_id     = "terraform@pve!mytoken"
  #proxmox_api_token_secret = "570e9eba-4e0b-4e67-b5f0-d6714cc2559e"
  # Qemu VM variables
  vm_count    = 3
  vm_name     = "k8snode"
  node        = "proxmox-pve01"
  cpu_cores   = 2
  cpu_sockets = 1
  memory      = 4096
  boot_order  = "order=scsi0;ide2;net0"
  #bios             = "ovmf"
  template_id      = 9003
  clone            = true
  storage_pool     = "local-lvm"
  iso_storage_pool = "local"
  disks = [
    {
      size    = "100G"
      storage = "nvme-storage"
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
    ip_address    = "192.168.1.130/24"
    enable_dhcp   = false
    nic           = "enp6s18"
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
