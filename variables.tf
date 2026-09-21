# ============================================================
# Proxmox Provider Variables
# ============================================================

variable "proxmox_api_url" {
  description = "Proxmox API URL, e.g. https://192.168.1.3:8006/api2/json"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox user name, e.g. 'terraform@pve'"
  type        = string
  default     = "terraform@pve"
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID, e.g. 'terraform@pve!mytoken'"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "ssh_keys" {
  description = "List of SSH public keys to inject into the VM"
  type        = list(string)
  default     = []
}

variable "generate_ssh_key" {
  description = "Auto-generate an SSH key pair and save it locally"
  type        = bool
  default     = false
}

# ============================================================
# QEMU / VM Variables
# ============================================================

variable "vm_name" {
  description = "Name of the Proxmox VM"
  type        = string
}

variable "node" {
  description = "Proxmox node where the VM will be created"
  type        = string
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Amount of RAM in MB"
  type        = number
  default     = 2048
}

variable "bios" {
  description = "BIOS type: 'seabios' for legacy BIOS, 'ovmf' for UEFI"
  type        = string
  default     = "seabios"
}

variable "boot_order" {
  description = "Boot device order string"
  type        = string
  default     = "order=scsi0;ide2;net0"
}

variable "template_id" {
  description = "VM ID of the Proxmox template to clone from"
  type        = number
  default     = null
}

variable "clone" {
  description = "Whether to clone from a template (true) or boot from ISO (false)"
  type        = bool
  default     = true
}

variable "storage_pool" {
  description = "Storage pool used for the EFI disk"
  type        = string
  default     = "local-lvm"
}

variable "iso_storage_pool" {
  description = "Storage pool used for the cloud-init ISO disk"
  type        = string
  default     = "local"
}

# ============================================================
# Disk Variables
# ============================================================

variable "disks" {
  description = "List of disk configurations to attach to the VM"
  type = list(object({
    size    = string
    storage = string
    type    = string
    slot    = string
    format  = optional(string, "raw")
    cache   = optional(string, "writeback")
    discard = optional(bool, true)
  }))
  default = [
    {
      size    = "20G"
      storage = "local-lvm"
      type    = "disk"
      slot    = "scsi0"
    }
  ]
}

# ============================================================
# Network Variables
# ============================================================

variable "networks" {
  description = "List of network interface configurations"
  type = list(object({
    id       = string
    bridge   = string
    model    = string
    tag      = optional(number)
    macaddr  = optional(string, null)
    firewall = optional(bool, false)
  }))
  default = [
    {
      id     = "0"
      bridge = "vmbr0"
      model  = "virtio"
    }
  ]
}

# ============================================================
# Cloud-Init Variables
# ============================================================

variable "cloudinit" {
  description = "Cloud-init configuration object passed to the proxmox-vm module"
  type = object({
    user_name                = optional(string, "cloud-user")
    user_fullname            = optional(string, "Cloud User")
    user_shell               = optional(string, "/bin/bash")
    user_password            = optional(string, null)
    set_user_password        = optional(bool, false)
    lock_user_password       = optional(bool, false)
    hostname                 = optional(string, "")
    timezone                 = optional(string, "UTC")
    manage_etc_hosts         = optional(bool, true)
    preserve_hostname        = optional(bool, true)
    enable_ssh_password_auth = optional(bool, false)
    disable_ssh_root_login   = optional(bool, true)
    lock_root_user_password  = optional(bool, false)
    set_root_password        = optional(bool, false)
    root_password            = optional(string, null)
    disable_ipv6             = optional(bool, false)
    package_update           = optional(bool, true)
    package_upgrade          = optional(bool, true)
    ip_address               = optional(string, "192.168.1.254/24")
    nic                      = optional(string, "ens18")
    gateway                  = optional(string, "192.168.1.1")
    enable_dhcp              = optional(bool, false)
    packages = optional(list(string), [
      "qemu-guest-agent",
      "vim",
      "wget",
      "curl",
      "unzip",
      "git"
    ])
    runcmds = optional(list(string), [
      "systemctl daemon-reload",
      "systemctl enable --now qemu-guest-agent",
      "systemctl restart systemd-networkd"
    ])
    dns_servers = optional(list(string), ["8.8.8.8", "8.8.4.4"])
  })
  default = {}
}

# ============================================================
# cicustom / Snippets Upload Variables
# ============================================================

variable "proxmox_node_host" {
  description = "IP or hostname of the Proxmox node for SSH snippet uploads. Defaults to the host parsed from proxmox_api_url."
  type        = string
  default     = ""
}

variable "proxmox_ssh_user" {
  description = "SSH user on the Proxmox node (usually root)"
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_path" {
  description = "Local path to the SSH private key used to authenticate to the Proxmox node (e.g. ~/.ssh/id_rsa)"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "snippets_storage" {
  description = "Proxmox storage pool with Snippets content type enabled (used for cicustom and cloudinit_cdrom_storage)"
  type        = string
  default     = "local"
}

variable "snippets_storage_path" {
  description = "Absolute filesystem path on the Proxmox node where snippets are stored (e.g. /var/lib/vz/snippets)"
  type        = string
  default     = "/var/lib/vz/snippets"
}

