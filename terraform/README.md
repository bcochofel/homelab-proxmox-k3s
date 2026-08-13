# Terraform

See [`../docs/TERRAFORM.md`](../docs/TERRAFORM.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.9.0, < 2.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | 2.9.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.85 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.0 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.111.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_k3s_agent"></a> [k3s\_agent](#module\_k3s\_agent) | ./modules/vm | n/a |
| <a name="module_k3s_server"></a> [k3s\_server](#module\_k3s\_server) | ./modules/vm | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [local_file.ansible_inventory](https://registry.terraform.io/providers/hashicorp/local/2.9.0/docs/resources/file) | resource |
| [proxmox_virtual_environment_vms.template](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_vms) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ansible_user"></a> [ansible\_user](#input\_ansible\_user) | Remote user Ansible connects as (matches ansible.cfg) | `string` | `"ubuntu"` | no |
| <a name="input_cipassword"></a> [cipassword](#input\_cipassword) | cloud-init user password | `string` | n/a | yes |
| <a name="input_ciuser"></a> [ciuser](#input\_ciuser) | cloud-init user (matches Packer template default user) | `string` | `"ubuntu"` | no |
| <a name="input_gateway"></a> [gateway](#input\_gateway) | Network gateway | `string` | `"192.168.68.1"` | no |
| <a name="input_k3s_agent_nodes"></a> [k3s\_agent\_nodes](#input\_k3s\_agent\_nodes) | K3s agent (worker) node definitions | <pre>list(object({<br/>    name    = string<br/>    vmid    = number<br/>    ip_cidr = string<br/>    cores   = number<br/>    memory  = number<br/>    disk    = number<br/>  }))</pre> | <pre>[<br/>  {<br/>    "cores": 2,<br/>    "disk": 50,<br/>    "ip_cidr": "192.168.68.26/22",<br/>    "memory": 4096,<br/>    "name": "k3s-agent1",<br/>    "vmid": 9551<br/>  },<br/>  {<br/>    "cores": 2,<br/>    "disk": 50,<br/>    "ip_cidr": "192.168.68.27/22",<br/>    "memory": 4096,<br/>    "name": "k3s-agent2",<br/>    "vmid": 9552<br/>  }<br/>]</pre> | no |
| <a name="input_k3s_server_nodes"></a> [k3s\_server\_nodes](#input\_k3s\_server\_nodes) | K3s server (control-plane) node definitions | <pre>list(object({<br/>    name    = string<br/>    vmid    = number<br/>    ip_cidr = string # e.g. 192.168.68.25/22<br/>    cores   = number<br/>    memory  = number # MB<br/>    disk    = number # GB<br/>  }))</pre> | <pre>[<br/>  {<br/>    "cores": 2,<br/>    "disk": 50,<br/>    "ip_cidr": "192.168.68.25/22",<br/>    "memory": 4096,<br/>    "name": "k3s-srv1",<br/>    "vmid": 9550<br/>  }<br/>]</pre> | no |
| <a name="input_nameserver"></a> [nameserver](#input\_nameserver) | DNS nameservers for cloud-init, in order (CoreDNS + Pihole — both, for redundancy) | `list(string)` | <pre>[<br/>  "192.168.68.42",<br/>  "192.168.68.43"<br/>]</pre> | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Proxmox network bridge | `string` | `"vmbr0"` | no |
| <a name="input_proxmox_api_token"></a> [proxmox\_api\_token](#input\_proxmox\_api\_token) | API token, form user@realm!tokenid=secret | `string` | n/a | yes |
| <a name="input_proxmox_endpoint"></a> [proxmox\_endpoint](#input\_proxmox\_endpoint) | Proxmox API endpoint, e.g. https://192.168.68.20:8006/ | `string` | n/a | yes |
| <a name="input_proxmox_insecure"></a> [proxmox\_insecure](#input\_proxmox\_insecure) | Skip TLS verification (homelab self-signed cert) | `bool` | `true` | no |
| <a name="input_proxmox_ssh_username"></a> [proxmox\_ssh\_username](#input\_proxmox\_ssh\_username) | SSH username for provider operations that require SSH | `string` | `"root"` | no |
| <a name="input_searchdomain"></a> [searchdomain](#input\_searchdomain) | DNS search domain | `string` | `"homelab.bcochofel.com"` | no |
| <a name="input_sshkeys"></a> [sshkeys](#input\_sshkeys) | Newline-delimited SSH public keys for the cloud-init user | `string` | n/a | yes |
| <a name="input_target_node"></a> [target\_node](#input\_target\_node) | Proxmox node name to place VMs on | `string` | `"pve1"` | no |
| <a name="input_vm_template"></a> [vm\_template](#input\_vm\_template) | Name of the Packer-built template to clone | `string` | `"ubuntu-26.04-k3s"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_agents"></a> [agents](#output\_agents) | K3s agent node name -> {vmid, ip} |
| <a name="output_servers"></a> [servers](#output\_servers) | K3s server node name -> {vmid, ip} |
<!-- END_TF_DOCS -->
