variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox User"
  type        = string
  default     = "terraform@pve"
}

# variable "proxmox_password" {
#   description = "Proxmox Password"
#   type        = string
#   sensitive   = true
# }

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "ssh_keys" {
  description = "List of SSH public keys to add to the VM"
  type        = list(string)
  default     = []
}
