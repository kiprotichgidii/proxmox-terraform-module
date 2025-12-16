# Proxmox VM Terraform Module

A comprehensive Terraform module for provisioning Virtual Machines on Proxmox VE. This module simplifies the creation of VMs by handling cloning, Cloud-Init configuration, storage, networking, and optional automatic secret generation.
To be honest, I only started developing this module to help me with my own use case. I work a lot with Proxmox VE and I needed a quick way to provision VMs in minutes, and Terraform is my close friend, so I went for it.

## 🚀 Features

- **Automated Provisioning**: Clone VMs from templates or create from ISO.
- **Advanced Cloud-Init**:
  - User & Root user management.
  - SSH key injection (existing + auto-generated).
  - Network configuration (DHCP or Static IP).
  - Package installation & custom commands.
- **Hardware Flexibility**:
  - Configurable CPU cores, sockets, and memory.
  - Multi-disk support with granular control (size, cache, format, storage pool).
  - Multi-network support (bridges, VLANs, firewalls).
- **Modern Boot Support**: Automatic UEFI (OVMF) configuration with EFI disk.
- **Security**:
  - Auto-generate SSH keys and passwords (optional).
  - Store secrets in local files for easy access.
  - Disable root SSH login, manage `/etc/hosts`.

## 📋 Requirements

Ensure your environment meets these requirements before using the module.

| Name | Version | Description |
|------|---------|-------------|
| **Terraform** | `>= 1.10.0` | Required Terraform version. |
| **Proxmox Provider** | `= 3.0.2-rc06` | Telmate/proxmox provider version. |
| **Proxmox VE** | `7.x/8.x` | Supported Proxmox versions. |

### Proxmox User Permissions
The user/token used must have at least `PVEVMAdmin` and `Datastore.Allocate` permissions on the target node and storage.

## 🛠 Usage
1. Create Proxmox VM Template
To use this modules, you need a VM template which will be clonesd by Terraform. Create a template using the disto's cloud image, e.g Debian, Ubuntu, etc.
```bash
qm create 9003 --name ubuntu24-template
qm set 9003 --scsi0 local-lvm:0,import-from=/root/cloud-images/ubuntu-24.04-server-cloudimg-amd64.img
qm template 9003
```

2. Clone this repository:

```bash
git clone https://github.com/kiprotichgidii/terraform-proxmox-module.git
```
Then edit the `main.tf` file in the root of the repo to match your Proxmox environment.

### Example Usage with Static IP, Multiple Disks, UEFI
This is an example that shows how to use the module to create a VM with multiple disks, UEFI boot, and static IP configuration.

```hcl
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
  proxmox_api_url  = "https://192.168.1.2:8006/api2/json"
  proxmox_user     = "terraform@pve"
  proxmox_password = "Xcqt0689"
  #proxmox_api_token_id     = "terraform@pve!mytoken"
  #proxmox_api_token_secret = "570e9eba-4e0b-4e67-b5f0-d6714cc2559e"
  # Qemu VM variables
  #vm_count     = 2
  vm_name          = "db-server"
  node             = "proxmox-pve01"
  cpu_cores        = 2
  cpu_sockets      = 1
  memory           = 4096
  boot_order       = "order=scsi0;ide2;net0"
  bios             = "ovmf"
  template_id      = 9003
  clone            = true
  storage_pool     = "nvme-storage"
  iso_storage_pool = "local"
  disks = [
    {
      size    = "40G"
      storage = "nvme-storage"
      type    = "disk"
      slot    = "scsi0"
      format  = "qcow2"
    },
    {
      size    = "100G"
      storage = "nvme-storage"
      type    = "disk"
      slot    = "scsi1"
      format  = "qcow2"
      cache   = "writeback"
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
    #nic           = "enp6s18"
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

```

## ⚙️ Configuration Reference

### Connection Variables
| Name | Type | Description | Required |
|------|------|-------------|:--------:|
| `proxmox_api_url` | string | URL of Proxmox API (e.g. `https://host:8006/api2/json`) | Yes |
| `proxmox_user` | string | Proxmox username (e.g. `terraform@pve`) | Yes |
| `proxmox_password` | string | Proxmox password | No |
| `proxmox_api_token_id` | string | API Token ID (alternative to password) | No |
| `proxmox_api_token_secret`| string | API Token Secret | No |
| `proxmox_tls_insecure` | bool | Skip TLS verification (Default: `true`) | No |

### VM Basics & Resources
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `vm_name` | string | (Required) | Name of the VM. |
| `vm_id` | number | `0` | Static VM ID. Set to `0` to let Proxmox auto-assign. |
| `vm_count` | number | `1` | Number of VM copies to create. |
| `node` | string | `"pve01"` | Target Proxmox Node. |
| `template_id` | number | `null` | ID of the template to clone. |
| `cpu_cores` | number | `2` | Number of CPU cores per socket. |
| `cpu_sockets` | number | `1` | Number of CPU sockets. |
| `memory` | number | `2048` | RAM in MB. |
| `bios` | string | `"seabios"` | BIOS type: `"seabios"` (default) or `"ovmf"` (UEFI). |
| `boot_order` | string | `...` | Boot order string (e.g., `"order=scsi0;ide2;net0"`). |

### Storage (`disks`)
List of objects with the following properties:
- `size` (Required): Disk size (e.g., `"20G"`).
- `storage` (Required): Proxmox storage pool name.
- `type`: Disk type (`"disk"`, `"cdrom"`, etc.).
- `slot`: Bus/Slot (e.g., `"scsi0"`, `"ide1"`).
- `format`: Disk format (`"qcow2"`, `"raw"`).
- `cache`: Caching mode (`"writeback"`, `"none"`, etc.).
- `discard`: Enable discard/trim (Default: `true`).

### Networking (`networks`)
List of objects with the following properties:
- `id`: Network Interface ID (0, 1, 2...).
- `bridge`: Bridge name (e.g., `"vmbr0"`).
- `model`: Interface model (Default: `"virtio"`).
- `macaddr`: Static MAC address (optional).
- `firewall`: Enable Proxmox firewall (Default: `false`).

### Cloud-Init (`cloudinit`)
Configuration object for the VM internals:
| Key | Default | Description |
|-----|---------|-------------|
| `user_name` | `"cloud-user"`| Default SSH user. |
| `user_password` | (Auto) | Sets user password if enabled. |
| `enable_ssh_password_auth`| `false` | Allow password auth for SSH. |
| `ip_address` | `"192.168.1.254/24"` | Static IP (CIDR format). |
| `gateway` | `"192.168.1.1"` | Network gateway. |
| `enable_dhcp` | `true` | overrides static IP settings. |
| `packages` | `[...]` | List of `apt` packages to install. |
| `runcmds` | `[...]` | List of shell commands to run on first boot. |
| `ssh_keys` | `[]` | List of **additional** public keys to inject. |

## 📤 Outputs

| Name | Description |
|------|-------------|
| `vmid` | The assigned VM ID(s). |
| `vm_ip_addresses` | Map of VM names to their IP addresses (if detected). |
| `ssh_commands` | Ready-to-use SSH connection strings. |
| `root_password` | The generated root password (if enabled). |
| `ssh_user` | The configured username. |

## ⚠️ Common Issues & Troubleshooting

### "Required attribute vm_id not specified"
This error occurs if `vm_id` is missing in `main.tf` logic.
**Fix**: Explicitly set `vm_id = 0` in your module block to enable automatic ID assignment by Proxmox.

### "Image not found"
Ensure the `storage` pool specified in `disks` exists on the target node.

### Cloud-Init not applying
- Ensure the OS template has `cloud-init` installed.
- Verify the `ide2` (Cloud-Init drive) is present in boot order or attached.

## 🤝 Contributing
Contributions, issues, and feature requests are welcome. To contirubute:
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License
MIT License.