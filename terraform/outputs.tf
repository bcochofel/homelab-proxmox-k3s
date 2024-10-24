output "servers" {
  value = {
    for k, v in resource.proxmox_vm_qemu.servers :
    k => {
      name = v.name
      ip   = split("=", split("/", v.ipconfig0)[0])[1]
    }
  }
}

output "servers_ips" {
  value = flatten([
    for srv_key, srv in resource.proxmox_vm_qemu.servers : [
      split("=", split("/", srv.ipconfig0)[0])[1]
    ]
  ])
}

output "agents" {
  value = {
    for k, v in resource.proxmox_vm_qemu.agents :
    k => {
      name = v.name
      ip   = split("=", split("/", v.ipconfig0)[0])[1]
    }
  }
}

output "agents_ips" {
  value = flatten([
    for srv_key, srv in resource.proxmox_vm_qemu.agents : [
      split("=", split("/", srv.ipconfig0)[0])[1]
    ]
  ])
}
