# Provider Configurations
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "= 3.0.2-rc06"
    }

    local = {
      source = "hashicorp/local"
    }

    tls = {
      source = "hashicorp/tls"
    }

    random = {
      source = "hashicorp/random"
    }

    template = {
      source = "hashicorp/template"
    }
  }
}
