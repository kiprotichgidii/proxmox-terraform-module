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

Login to your Proxmox VE host via SSH and create an API token with permissions as follows:

For PVE 9 and newer:

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Pool.Audit Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use"
pveum user add terraform-prov@pve --password <password>
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

For PVE 8 and older:

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Migrate VM.PowerMgmt SDN.Use"
pveum user add terraform-prov@pve --password <password>
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

It is recommended to use API tokens instead of passwords.

```bash
pveum user token add terraform-prov@pve mytoken
```
For some reason, using an API token with privilege separation on, does not work with Terraform. On your PVE console. go to Datacenter => Permissions => API Tokens => Click on the API token you just created => Disable privilege separation, and everything should work as expected.

## 🛠 Usage
### Create Proxmox VM Template

To use this modules, you need a VM template which will be clonesd by Terraform. Create a template using the disto's cloud image, e.g Debian, Ubuntu, etc.
```bash
qm create 9003 --name ubuntu24-template
qm set 9003 --scsi0 local-lvm:0,import-from=/root/cloud-images/ubuntu-24.04-server-cloudimg-amd64.img
qm template 9003
```

### Create a main.tf file and a variables.tf file

```bash
touch main.tf && touch variables.tf
```
Copy paste the content from the `main.tf` and `variables.tf` file in the `example` folder to match your Proxmox environment and configure your VM resources. Then create a terraform.tfvars file and add your variables as follows:

```bash
cat <<EOF > terraform.tfvars

proxmox_api_url          = "https://your-proxmox-ip:8006/api2/json"
proxmox_user             = "terraform@pve"
proxmox_api_token_id     = "your-token-id"
proxmox_api_token_secret = "your-token-secret"

EOF
```

### Example: Static IP, Multiple Disks, UEFI
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
  #vm_count         = 2
  vm_name          = "Rocky-Linux-10"
  node             = "pve02"
  cpu_cores        = 2
  cpu_sockets      = 1
  memory           = 4096
  bios             = "ovmf"
  boot_order       = "order=scsi0;ide2"
  template_id      = 8807
  clone            = true
  storage_pool     = "local-lvm"
  iso_storage_pool = "local"
  disks = [
    {
      size    = "50G"
      storage = "zfs-pool"
      type    = "disk"
      slot    = "scsi0"
      format  = "raw"
    },
    {
      size    = "40G"
      storage = "zfs-pool"
      type    = "disk"
      slot    = "scsi1"
      format  = "raw"
      cache   = "writeback"
    }
  ]
  networks = [
    {
      id     = "0"
      bridge = "vmbr0"
      model  = "virtio"
      #tag    = "30"
    }
  ]
  cloudinit = {
    user_name     = "korir"
    user_fullname = "Nai Korir"
    user_password = "Password@123!"
    timezone      = "Africa/Nairobi"
    ip_address  = "192.168.1.62/24"
    gateway     = "192.168.1.1"
    #nic         = "enp6s18"
    enable_ssh_password_auth = true
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

### Example: Password Configuration

```hcl
module "proxmox_vm" {
  source = "git::https://github.com/kiprotichgidii/proxmox-terraform-module.git//modules/proxmox-vm?ref=main"

  # ... (other required variables)

  cloudinit = {
    user_name = "admin"

    # Option A: provide your own plaintext password
    user_password = "MySecureP@ss1"

    # Option B: auto-generate a random password (saved to user_password.txt)
    # set_user_password = true

    # Allow console/SSH password login (disabled by default)
    enable_ssh_password_auth = true
  }
}
```

> [!NOTE]
> When using a static IP, always set `gateway` and `nic` explicitly. The NIC name depends on your VM template — run `ip link` inside the template to confirm it (typically `ens18` for SCSI, `enp6s18` for virtio on a q35 machine).


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
| `clone` | bool | `null` | Whether to clone from a template (`true`) or create fresh. |
| `iso` | string | `null` | ISO image path to use when not cloning (e.g. `"local:iso/debian.iso"`). |
| `cpu_cores` | number | `2` | Number of CPU cores per socket. |
| `cpu_sockets` | number | `1` | Number of CPU sockets. |
| `memory` | number | `2048` | RAM in MB. |
| `bios` | string | `"seabios"` | BIOS type: `"seabios"` (legacy) or `"ovmf"` (UEFI). |
| `machine_type` | string | `"q35"` | Machine type (e.g. `"q35"`, `"i440fx"`). |
| `boot_order` | string | `"order=scsi0;ide2;net0"` | Boot order string. |
| `scsi_hardware` | string | `"virtio-scsi-single"` | SCSI controller type. |
| `vm_state` | string | `"running"` | Desired VM state: `"running"`, `"stopped"`, or `"started"`. |
| `autostart` | bool | `true` | Start VM automatically when the Proxmox host boots. |
| `qemu_agent` | number | `1` | Enable (`1`) or disable (`0`) the QEMU Guest Agent. |
| `agent_timeout` | number | `180` | Seconds to wait for the QEMU Guest Agent to respond. |
| `skip_ipv6` | bool | `true` | Tell Proxmox not to wait for an IPv6 address from the guest agent. |
| `storage_pool` | string | `"local-lvm"` | Default storage pool for VM disks and EFI disk. |
| `iso_storage_pool` | string | `"local"` | Storage pool for the generated cloud-init ISO. Must be file-based (e.g. `local`). |
| `tags` | list(string) | `[]` | List of Proxmox tags to apply to the VM. |
| `generate_ssh_key` | bool | `true` | Auto-generate an RSA SSH key pair and save to disk. |
| `ssh_keys` | list(string) | `[]` | List of existing SSH public keys to inject into the VM. |

### Storage (`disks`)
List of objects with the following properties:

| Key | Required | Default | Description |
|-----|:--------:|---------|-------------|
| `size` | Yes | — | Disk size (e.g. `"20G"`). |
| `storage` | Yes | — | Proxmox storage pool name. |
| `type` | Yes | — | Disk role: `"disk"`, `"cdrom"`. |
| `slot` | Yes | — | Bus/slot identifier (e.g. `"scsi0"`, `"ide1"`). |
| `format` | No | `"qcow2"` | Disk image format: `"qcow2"`, `"raw"`. |
| `cache` | No | `"writeback"` | Caching mode: `"writeback"`, `"none"`, `"directsync"`, etc. |
| `discard` | No | `true` | Enable discard/TRIM passthrough. |
| `iothread` | No | `false` | Enable a dedicated I/O thread for this disk (improves performance). |

### Networking (`networks`)
List of objects with the following properties:

| Key | Required | Default | Description |
|-----|:--------:|---------|-------------|
| `id` | Yes | — | Network interface index (e.g. `"0"`, `"1"`). |
| `bridge` | Yes | — | Proxmox bridge name (e.g. `"vmbr0"`). |
| `model` | Yes | — | NIC model (e.g. `"virtio"`, `"e1000"`). |
| `tag` | No | `null` | VLAN tag ID. |
| `macaddr` | No | `null` | Static MAC address. |
| `firewall` | No | `false` | Enable Proxmox firewall on this interface. |

### Cloud-Init (`cloudinit`)
Configuration object for in-guest settings applied via Cloud-Init:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `user_name` | string | `"cloud-user"` | Default SSH/login user. |
| `user_fullname` | string | `"Cloud User"` | Full name (GECOS field). |
| `user_shell` | string | `"/bin/bash"` | Default user shell. |
| `hostname` | string | `""` | Custom hostname (defaults to `<vm_name>-<index>`). |
| `timezone` | string | `"UTC"` | System timezone (e.g. `"Africa/Nairobi"`). |
| `manage_etc_hosts` | bool | `true` | Allow Cloud-Init to manage `/etc/hosts`. |
| `preserve_hostname` | bool | `true` | Preserve hostname across reboots. |
| `enable_ssh_password_auth` | bool | `false` | Allow password-based SSH authentication. Set to `true` to log in with a password over SSH. |
| `disable_ssh_root_login` | bool | `true` | Disable SSH login as root. |
| `lock_root_user_password` | bool | `false` | Lock the root account password. |
| `set_root_password` | bool | `false` | Auto-generate a random root password (saved to `root_password.txt`). Ignored if `root_password` is set. |
| `root_password` | string | `null` | Plaintext root password. Takes precedence over `set_root_password`. No file is written to disk. |
| `set_user_password` | bool | `false` | Auto-generate a random user password (saved to `user_password.txt`). Ignored if `user_password` is set. |
| `user_password` | string | `null` | Plaintext user password. Takes precedence over `set_user_password`. No file is written to disk. |
| `lock_user_password` | bool | `false` | Lock the default user password. |
| `disable_ipv6` | bool | `false` | Disable IPv6 networking via sysctl. |
| `ip_address` | string | `"192.168.1.254/24"` | Static IP in CIDR format. Used when `enable_dhcp = false`. |
| `gateway` | string | `"192.168.1.1"` | Default gateway. Used when `enable_dhcp = false`. |
| `nic` | string | `"ens18"` | Network interface name inside the guest (e.g. `"enp6s18"` for virtio on q35). Run `ip link` on your template to confirm. |
| `enable_dhcp` | bool | `false` | Use DHCP instead of a static IP. When `true`, `ip_address` and `gateway` are ignored. |
| `dns_servers` | list(string) | `["8.8.8.8", "8.8.4.4"]` | List of DNS resolver addresses. |
| `package_update` | bool | `true` | Run package index update on first boot. |
| `package_upgrade` | bool | `true` | Run full package upgrade on first boot. |
| `packages` | list(string) | `["qemu-guest-agent", "vim", ...]` | Additional packages to install on first boot. |
| `runcmds` | list(string) | `["systemctl enable --now qemu-guest-agent", ...]` | Shell commands to execute on first boot. |

> [!NOTE]
> Password login over SSH requires **both** a password to be set (`user_password` or `set_user_password = true`) **and** `enable_ssh_password_auth = true`. Console login only requires a password to be set.

## 📤 Outputs

| Name | Description |
|------|-------------|
| `vmid` | Map of VM name → assigned VM ID. |
| `name` | Map of VM name → VM name (for reference). |
| `node` | Map of VM name → Proxmox node the VM was created on. |
| `status` | Map of VM name → current VM state (`running`, `stopped`). |
| `vm_ip_addresses` | Map of VM name → primary IPv4 address (reported by guest agent). |
| `ssh_user` | Map of VM name → configured SSH username. |
| `ssh_user_password` | Map of VM name → generated user password (sensitive, if `set_user_password = true`). |
| `root_password` | Map of VM name → generated root password (sensitive, if `set_root_password = true`). |
| `ssh_commands` | Map of VM name → ready-to-use `ssh` command string. |

## ⚠️ Common Issues & Troubleshooting

#### ❌ Error: `Image not found`
Ensure the `storage` pool specified in `disks` exists on the target node.

#### ❌ Error: `500 can't upload to storage type 'lvmthin'`
Cloud-init ISOs must be stored on file-based storage (e.g. `local`).
They cannot be uploaded to `lvmthin` or `local-lvm`.
  - 🛠 **Fix** : Set `iso_storage_pool` to `local` or any other configured storage pool.

#### ❌ Error: `500 you can't move to the same storage with same format`

➡️ The VM is being created with a disk that is already on the same storage, using the same format, and Proxmox refuses the “move/convert” operation. This only happens when Proxmox thinks you are trying to move or convert a disk that is already in the correct place.
  - 🛠 **Fix** : Set `disk_format` to `raw` if template is `qcow2` or Use a different storage pool.

#### ❌ Error: `CentOS Stream images may fail to boot when using UEFI`
CentOS Stream images may fail to boot when using UEFI (`bios = "ovmf"`).
  - 🛠 **Fix** : Ensure your base image supports UEFI. If issues persist, switch to `bios = "seabios"`.

#### ❌ VM ignores the static IP and gets one from DHCP instead
The cloud-init `network_config` is using a format the guest OS doesn't understand (e.g. Netplan v2 on Rocky/RHEL), or `gateway` / `nic` are not set.
  - 🛠 **Fix** : Set both `gateway` and `nic` explicitly in the `cloudinit` block. The `nic` name varies by machine type — run `ip link` inside your template to confirm (typically `ens18` for SCSI, `enp6s18` for virtio on q35).

#### ❌ Password set via `set_user_password`/`user_password` is not working
Cloud-init may have failed schema validation, causing the password module to be skipped. Verify with:
```bash
sudo cloud-init status --long
sudo cloud-init schema --system
```
Common causes:
  - **`cloud-config failed schema validation`**: Check the schema output for unexpected properties. Run `sudo cloud-init schema --system` for the full error list.
  - **`Not unlocking password ... no 'passwd'/'hashed_passwd' provided`**: The password was not embedded in the `users:` block. This is resolved in the current module version.
  - 🛠 **Fix** : Ensure you are using the latest module version and redeploy with `terraform destroy && terraform apply`.

## 🤝 Contributing
Contributions, issues, and feature requests are welcome. To contribute:
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License
Apache 2.0
