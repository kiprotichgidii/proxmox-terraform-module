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
  # provider Variables
  proxmox_api_url  = "https://192.168.1.3:8006/api2/json"
  proxmox_user     = "root@pam"
  proxmox_password = "Nerdy@Kim!"
  #proxmox_api_token_id     = "terraform@pve!mytoken"
  #proxmox_api_token_secret = "570e9eba-4e0b-4e67-b5f0-d6714cc2559e"
  # Qemu VM variables
  #vm_count     = 2
  vm_name          = "db-server"
  node             = "pve03"
  cpu_cores        = 2
  cpu_sockets      = 1
  memory           = 4096
  boot_order       = "order=scsi0;ide2;net0"
  bios             = "ovmf"
  template_id      = 9001
  clone            = true
  storage_pool     = "zfs-pool"
  iso_storage_pool = "local"
  disks = [
    {
      size    = "40G"
      storage = "zfs-pool"
      type    = "disk"
      slot    = "scsi0"
      format  = "raw"
    },
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
    ip_address    = "192.168.1.132/24"
    nic           = "enp6s18"
    enable_dhcp   = false
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
