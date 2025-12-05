output "vmid" {
  description = "The ID of the created virtual machine"
  value       = try(proxmox_vm_qemu.qemu_vm[0].vmid)
}

output "name" {
  value       = try(proxmox_vm_qemu.qemu_vm[0].name)
  description = "The name of the created virtual machine"
}

output "node" {
  value       = try(proxmox_vm_qemu.qemu_vm[0].target_node)
  description = "The node the VM was created on"
}

output "status" {
  value       = try(proxmox_vm_qemu.qemu_vm[0].vm_state)
  description = "The status of the QEMU VM"
}

output "ssh_user" {
  description = "The SSH user for the VM"
  value       = var.cloudinit.user_name
}

output "ssh_user_password" {
  description = "The SSH password for the VM (if set to be generated)"
  value       = var.cloudinit.set_user_password ? random_password.user_password[0].result : ""
  sensitive   = true
}

output "root_password" {
  description = "The root password for the VM (if set to be generated)"
  value       = var.cloudinit.set_root_password ? random_password.root_password[0].result : ""
  sensitive   = true
}

output "vm_ip_addresses" {
  description = "The IP addresses assigned to the VM via cloud-init"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => try(vm.network[0].ip_address, "N/A")
  }
}

output "ssh_commands" {
  description = "SSH commands to connect to the created VMs"
  value = {
    for idx, vm in proxmox_vm_qemu.qemu_vm :
    vm.name => format("ssh -i %s %s@%s", "${path.cwd}/id_rsa.key", var.cloudinit.user_name, try(vm.network[0].ip-address, "N/A"))
  }
}
