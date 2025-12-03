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
  proxmox_api_url          = "https://192.168.1.2:8006/api2/json"
  proxmox_user             = "terraform@pve"
  proxmox_api_token_id     = "terraform@pve!mytoken"
  proxmox_api_token_secret = "570e9eba-4e0b-4e67-b5f0-d6714cc2559e"
  # Qemu VM variables
  vm_id        = 155
  vm_name      = "db-server"
  node         = "proxmox-pve01"
  cpu_cores    = 2
  cpu_sockets  = 1
  memory       = 4096
  boot_order   = "order=scsi0;ide2;net0"
  template_id  = 9000
  clone        = true
  storage_pool = "local-lvm"
  disks = [
    {
      
      size    = "32G"
      storage = "local-lvm"
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
    user_name = "cloudinit"
    timezone = "Africa/Nairobi"
  }

}