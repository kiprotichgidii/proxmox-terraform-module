variable "proxmox_api_url" {
  description = "The Proxmox API URL, e.g https://proxmox.example.com:8006/api2/json"
  type        = string
}

variable "proxmox_user" {
  description = "The Proxmox user name, e.g. 'root@pam' or 'terraform@pve'"
  type        = string
}

variable "proxmox_password" {
  description = "The Proxmox user password"
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_api_token_id" {
  description = "The Proxmox API token ID, e.g. 'terraform@pve!mytokenid'"
  type        = string
  default     = ""
}

variable "proxmox_api_token_secret" {
  description = "The Proxmox API token secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Disable TLS certificate verification"
  type        = bool
  default     = true
}

variable "node" {
  description = "The Proxmox node name where the VM will be created"
  type        = string
  default     = "pve01"
}

variable "vm_count" {
  description = "Number of VM instances to create"
  type        = number
  default     = 1
}

variable "vm_id" {
  description = "The VM ID for the Proxmox VM"
  type        = number
}

variable "vm_name" {
  description = "The name of the Proxmox VM"
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

variable "tablet" {
  description = "Enable/disable the USB tablet device."
  type        = bool
  default     = true
}

variable "boot_order" {
  description = "Boot device order"
  type        = string
  default     = "order=scsi0;ide2;net0"
}

variable "bios" {
  description = "The BIOS to use i.e seabios for legacy, ovmf for UEFI"
  type        = string
  default     = "seabios"
}

variable "machine_type" {
  description = "The machine type"
  type        = string
  default     = "q35"
}

variable "disks" {
  description = "List of disk configurations"
  type = list(object({
    id       = optional(string)
    size     = string
    storage  = string
    type     = string
    slot     = string
    cache    = optional(string, "writeback")
    format   = optional(string, "qcow2")
    discard  = optional(bool, "true")
    iothread = optional(bool, "false")
  }))
  default = [
    {
      id      = ""
      size    = "20G"
      storage = "local-lvm"
      type    = "disk"
      slot    = "scsi0"
    }
  ]
}

variable "networks" {
  description = "List of network configurations"
  type = list(object({
    id       = string
    bridge   = string
    model    = string
    macaddr  = optional(string)
    firewall = optional(bool)
  }))
  default = [
    {
      id       = "0"
      bridge   = "vmbr0"
      model    = "virtio"
      macaddr  = null
      firewall = false
    }
  ]
}

variable "ssh_keys" {
  description = "List of SSH public keys to add to the VM"
  type        = list(string)
  default     = []
}

variable "cloudinit" {
  description = "SSH Public keys for cloudinit user"
  type = object({
    user_name                = optional(string)
    hostname                 = optional(string)
    timezone                 = optional(string)
    manage_etc_hosts         = optional(bool)
    preserve_hostname        = optional(bool)
    enable_ssh_password_auth = optional(bool)
    disable_ssh_root_login   = optional(bool)
    lock_root_user_password  = optional(bool)
    set_root_password        = optional(bool)
    set_user_password        = optional(bool)
    lock_user_password       = optional(bool)
    ssh_user_fullname        = optional(string)
    ssh_user_shell           = optional(string)
    disable_ipv6             = optional(bool)
    package_update           = optional(bool)
    package_upgrade          = optional(bool)
    packages                 = optional(list(string))
    runcmds                  = optional(list(string))
    ip_address               = optional(string)
    nic                      = optional(string)
    gateway                  = optional(string)
    dns_servers              = optional(list(string))
    enable_dhcp              = optional(bool)
  })
  default = {
    user_name                = "cloud-user"
    hostname                 = ""
    timezone                 = "UTC"
    manage_etc_hosts         = true
    preserve_hostname        = true
    enable_ssh_password_auth = false
    disable_ssh_root_login   = true
    lock_root_user_password  = false
    set_root_password        = false
    set_user_password        = false
    lock_user_password       = false
    ssh_user_fullname        = "Cloud User"
    ssh_user_shell           = "/bin/bash"
    disable_ipv6             = false
    package_update           = true
    package_upgrade          = true
    ip_address               = "192.168.1.254/24"
    nic                      = "ens3"
    gateway                  = "192.168.1.1"
    enable_dhcp              = false
    dns_servers = [
      "8.8.8.8",
      "8.8.4.4"
    ]
    packages = [
      "qemu-guest-agent",
      "vim",
      "wget",
      "curl",
      "unzip",
      "git"
    ]
    runcmds = [
      "systemctl daemon-reload",
      "systemctl enable --now qemu-guest-agent",
      "systemctl restart systemd-networkd"
    ]
  }
}

variable "vm_state" {
  description = "The desired state of the VM"
  type        = string
  default     = "running"
}

variable "clone" {
  description = "Clone configuration"
  type        = bool
  default     = null
}

variable "onboot" {
  description = "Set VM to start on host boot"
  type        = bool
  default     = true
}

variable "qemu_agent" {
  description = "Enable QEMU Guest Agent"
  type        = bool
  default     = true
}

variable "template_id" {
  description = "The VM ID of the template to clone from"
  type        = number
  default     = null
}

variable "iso" {
  description = "ISO image to use if not clonning"
  type        = string
  default     = null
}

variable "scsi_hardware" {
  description = "The SCSI controller to emulate"
  type        = string
  default     = "virtio-scsi-single"
}

variable "storage_pool" {
  description = "The resource pool to which the VM will be added."
  type        = string
  default     = "local-lvm"
}

variable "autostart" {
  description = "Autostart flag"
  type        = bool
  default     = true
}

variable "tags" {
  description = "List of tags"
  type        = list(string)
  default     = []
}

variable "generate_ssh_key" {
  description = "Generate an SSH key pair"
  type        = bool
  default     = true
}