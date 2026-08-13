output "servers" {
  description = "K3s server node name -> {vmid, ip}"
  value = {
    for k, v in module.k3s_server :
    k => { vmid = v.vmid, ip = v.ip }
  }
}

output "agents" {
  description = "K3s agent node name -> {vmid, ip}"
  value = {
    for k, v in module.k3s_agent :
    k => { vmid = v.vmid, ip = v.ip }
  }
}
