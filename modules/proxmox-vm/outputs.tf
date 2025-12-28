output "vmid" {
  description = "The ID of the created virtual machine"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => try(vm.vmid)
  }
}

output "name" {
  description = "The name of the created virtual machine"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => try(vm.name)
  }
}

output "node" {
  description = "The node the VM was created on"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => try(vm.target_node)
  }
}

output "status" {
  description = "The status of the QEMU VM"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => try(vm.vm_state)
  }
}

output "ssh_user" {
  description = "The SSH user for the VM"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => try(var.cloudinit.user_name)
  }
}

output "ssh_user_password" {
  description = "The SSH password for the VM (if set to be generated)"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => try(var.cloudinit.set_user_password ? random_password.user_password[0].result : "")
  }
  sensitive = true
}

output "root_password" {
  description = "The root password for the VM (if set to be generated)"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => try(var.cloudinit.set_root_password ? random_password.root_password[0].result : "")
  }
  sensitive = true
}

output "vm_ip_addresses" {
  description = "The IP addresses assigned to the VM via cloud-init"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => try(vm.default_ipv4_address, "N/A")
  }
}

output "ssh_commands" {
  description = "SSH commands to connect to the created VMs"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => format("ssh -i %s %s@%s", "${path.cwd}/id_rsa.key", var.cloudinit.user_name, try(vm.default_ipv4_address, "N/A"))
  }
}
