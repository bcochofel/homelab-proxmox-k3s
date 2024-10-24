# Create nodes for K3s cluster

Create a K3s cluster on Proxmox using Terraform and Ansible.

This repository is a follow-up to [this](https://github.com/bcochofel/homelab-proxmox-core), so check that for the initial setup.

## Terraform

To create the virtual machines for the cluster

```bash
terraform init
terraform plan
terraform apply -parallelism=1
```

The reason for the "-parallelism=1" is because Proxmox locks the template to clone the VM, and can only create one at a time.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 3.0.1-rc4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.6.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 3.0.1-rc4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_vm_qemu.agents](https://registry.terraform.io/providers/Telmate/proxmox/3.0.1-rc4/docs/resources/vm_qemu) | resource |
| [proxmox_vm_qemu.servers](https://registry.terraform.io/providers/Telmate/proxmox/3.0.1-rc4/docs/resources/vm_qemu) | resource |
| [random_pet.agent_name](https://registry.terraform.io/providers/hashicorp/random/3.6.3/docs/resources/pet) | resource |
| [random_pet.server_name](https://registry.terraform.io/providers/hashicorp/random/3.6.3/docs/resources/pet) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_agent"></a> [default\_agent](#input\_default\_agent) | Set to 1 to enable the QEMU Guest Agent. | `number` | `1` | no |
| <a name="input_default_boot"></a> [default\_boot](#input\_default\_boot) | The boot order for the VM. | `string` | `"order=scsi0"` | no |
| <a name="input_default_clone"></a> [default\_clone](#input\_default\_clone) | The base VM from which to clone to create the new VM. | `string` | `"ubuntu-noble-tmpl"` | no |
| <a name="input_default_cores"></a> [default\_cores](#input\_default\_cores) | The number of CPU cores per CPU socket to allocate to the VM. | `number` | `2` | no |
| <a name="input_default_desc"></a> [default\_desc](#input\_default\_desc) | The description of the VM. | `string` | `""` | no |
| <a name="input_default_disk_format"></a> [default\_disk\_format](#input\_default\_disk\_format) | The drive’s backing file’s data format. | `string` | `"raw"` | no |
| <a name="input_default_disk_size"></a> [default\_disk\_size](#input\_default\_disk\_size) | The size of the created disk, format must match the regex \d+[GMK] | `string` | `"40G"` | no |
| <a name="input_default_disk_storage"></a> [default\_disk\_storage](#input\_default\_disk\_storage) | The name of the storage pool on which to store the disk. | `string` | `"local-lvm"` | no |
| <a name="input_default_full_clone"></a> [default\_full\_clone](#input\_default\_full\_clone) | Set to true to create a full clone, or false to create a linked clone. | `bool` | `true` | no |
| <a name="input_default_ipconfig0"></a> [default\_ipconfig0](#input\_default\_ipconfig0) | The first IP address to assign to the guest. | `string` | `"ip=dhcp"` | no |
| <a name="input_default_memory"></a> [default\_memory](#input\_default\_memory) | The amount of memory to allocate to the VM in Megabytes. | `number` | `2048` | no |
| <a name="input_default_nameserver"></a> [default\_nameserver](#input\_default\_nameserver) | Sets default DNS server for guest. | `string` | `"192.168.68.2"` | no |
| <a name="input_default_network_bridge"></a> [default\_network\_bridge](#input\_default\_network\_bridge) | Bridge to which the network device should be attached. | `string` | `"vmbr0"` | no |
| <a name="input_default_network_model"></a> [default\_network\_model](#input\_default\_network\_model) | Network Card Model. | `string` | `"virtio"` | no |
| <a name="input_default_onboot"></a> [default\_onboot](#input\_default\_onboot) | Whether to have the VM startup after the PVE node starts. | `bool` | `true` | no |
| <a name="input_default_os_type"></a> [default\_os\_type](#input\_default\_os\_type) | Which provisioning method to use, based on the OS type. | `string` | `"cloud-init"` | no |
| <a name="input_default_pool"></a> [default\_pool](#input\_default\_pool) | The resource pool to which the VM will be added. | `string` | `""` | no |
| <a name="input_default_scsihw"></a> [default\_scsihw](#input\_default\_scsihw) | The SCSI controller to emulate. | `string` | `"virtio-scsi-pci"` | no |
| <a name="input_default_searchdomain"></a> [default\_searchdomain](#input\_default\_searchdomain) | Sets default DNS search domain suffix. | `string` | `"homelab.bcochofel.com"` | no |
| <a name="input_default_sockets"></a> [default\_sockets](#input\_default\_sockets) | The number of CPU sockets to allocate to the VM. | `number` | `1` | no |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Tags of the VM. | `string` | `"terraform"` | no |
| <a name="input_default_target_node"></a> [default\_target\_node](#input\_default\_target\_node) | The default name of the Proxmox Node on which to place the VM. | `string` | `"pve1"` | no |
| <a name="input_default_vmid"></a> [default\_vmid](#input\_default\_vmid) | The ID of the VM in Proxmox. | `number` | `0` | no |
| <a name="input_k3s_agent_nodes"></a> [k3s\_agent\_nodes](#input\_k3s\_agent\_nodes) | A map of K3s Agent Nodes to be created.<br>map(object({<br>  name = (Optional) The name of the VM within Proxmox. If not set will be generated.<br>  target\_node = (Optional) The name of the Proxmox Node on which to place the VM. If not set will be the value of the default\_target\_node.<br>  vmid = (Optional) The ID of the VM in Proxmox. If not set will be the value of default\_vmid.<br>  desc = (Optional) The description of the VM. Shows as the 'Notes' field in the Proxmox GUI. If not set will be the value of default\_desc.<br>  onboot = (Optional) Whether to have the VM startup after the PVE node starts. If not set will be the value of default\_onboot.<br>  boot = (Optional) The boot order for the VM. For example: order=scsi0;ide2;net0. If not set will be the value of default\_boot.<br>  agent = (Optional) Set to 1 to enable the QEMU Guest Agent. Note, you must run the qemu-guest-agent daemon in the guest for this to have any effect. If not set will be the value of default\_agent.<br>  clone = (Optional) The base VM from which to clone to create the new VM. If not set will be the value of default\_clone.<br>  full\_clone = (Optional) Set to true to create a full clone, or false to create a linked clone. If not set will be the value of default\_full\_clone.<br>  memory = (Optional) The amount of memory to allocate to the VM in Megabytes. If not set will be the value of default\_memory.<br>  sockets = (Optional) The number of CPU sockets to allocate to the VM. If not set will be the value of default\_sockets.<br>  cores = (Optional) The number of CPU cores per CPU socket to allocate to the VM. If not set will be the value of default\_cores.<br>  scsihw = (Optional) The SCSI controller to emulate. If not set will be the value of default\_scsihw.<br>  pool = (Optional) The resource pool to which the VM will be added. If not set will be the value of default\_pool.<br>  tags = (Optional) Tags of the VM. Comma-separated values (e.g. tag1,tag2,tag3). Tag may only include the following characters: [a-z], [0-9] and \_. This is only meta information. If not set will be the value of default\_tags.<br>  os\_type = (Optional) Which provisioning method to use, based on the OS type. If not set will be the value of default\_os\_type.<br>  searchdomain = (Optional) Sets default DNS search domain suffix. If not set will be the value of default\_searchdomain.<br>  nameserver = (Optional) Sets default DNS server for guest. If not set will be the value of default\_nameserver.<br>  ipconfig0 = (Optional) The first IP address to assign to the guest. If not set will be the value of default\_ipconfig0.<br>  network = optional(object({<br>    model = (Optional) Network Card Model. The virtio model provides the best performance with very low CPU overhead. If not set will be the value of default\_network\_model.<br>    bridge = (Optional) Bridge to which the network device should be attached. If not set will be the value of default\_network\_bridge.<br>  }))<br>  disk = optional(object({<br>    size = (Optional) The size of the additional disk. Accepts K for kibibytes, M for mebibytes, G for gibibytes, T for tibibytes. If not set will be the value of default\_disk\_size.<br>    storage = (Optional) The name of the storage pool on which to store the disk. If not set will be the value of default\_disk\_storage.<br>    format = (Optional) The drive’s backing file’s data format. If not set will be the value of default\_disk\_format.<br>  }))<br>}))<br><br>The disk map is for an additional disk only. | <pre>map(object({<br>    name         = optional(string)<br>    target_node  = optional(string)<br>    vmid         = optional(number)<br>    desc         = optional(string)<br>    onboot       = optional(bool)<br>    boot         = optional(string)<br>    agent        = optional(number)<br>    clone        = optional(string)<br>    full_clone   = optional(bool)<br>    memory       = optional(number)<br>    sockets      = optional(number)<br>    cores        = optional(number)<br>    scsihw       = optional(string)<br>    pool         = optional(string)<br>    tags         = optional(string)<br>    os_type      = optional(string)<br>    searchdomain = optional(string)<br>    nameserver   = optional(string)<br>    ipconfig0    = optional(string)<br>    network = optional(object({<br>      model  = optional(string)<br>      bridge = optional(string)<br>    }))<br>    disk = optional(object({<br>      size    = optional(string)<br>      storage = optional(string)<br>      format  = optional(string)<br>    }))<br>  }))</pre> | <pre>{<br>  "agent1": {<br>    "ipconfig0": "ip=192.168.68.40/22,gw=192.168.68.1"<br>  },<br>  "agent2": {<br>    "ipconfig0": "ip=192.168.68.41/22,gw=192.168.68.1"<br>  },<br>  "agent3": {<br>    "ipconfig0": "ip=192.168.68.42/22,gw=192.168.68.1"<br>  }<br>}</pre> | no |
| <a name="input_k3s_server_nodes"></a> [k3s\_server\_nodes](#input\_k3s\_server\_nodes) | A map of K3s Server Nodes to be created.<br>map(object({<br>  name = (Optional) The name of the VM within Proxmox. If not set will be generated.<br>  target\_node = (Optional) The name of the Proxmox Node on which to place the VM. If not set will be the value of the default\_target\_node.<br>  vmid = (Optional) The ID of the VM in Proxmox. If not set will be the value of default\_vmid.<br>  desc = (Optional) The description of the VM. Shows as the 'Notes' field in the Proxmox GUI. If not set will be the value of default\_desc.<br>  onboot = (Optional) Whether to have the VM startup after the PVE node starts. If not set will be the value of default\_onboot.<br>  boot = (Optional) The boot order for the VM. For example: order=scsi0;ide2;net0. If not set will be the value of default\_boot.<br>  agent = (Optional) Set to 1 to enable the QEMU Guest Agent. Note, you must run the qemu-guest-agent daemon in the guest for this to have any effect. If not set will be the value of default\_agent.<br>  clone = (Optional) The base VM from which to clone to create the new VM. If not set will be the value of default\_clone.<br>  full\_clone = (Optional) Set to true to create a full clone, or false to create a linked clone. If not set will be the value of default\_full\_clone.<br>  memory = (Optional) The amount of memory to allocate to the VM in Megabytes. If not set will be the value of default\_memory.<br>  sockets = (Optional) The number of CPU sockets to allocate to the VM. If not set will be the value of default\_sockets.<br>  cores = (Optional) The number of CPU cores per CPU socket to allocate to the VM. If not set will be the value of default\_cores.<br>  scsihw = (Optional) The SCSI controller to emulate. If not set will be the value of default\_scsihw.<br>  pool = (Optional) The resource pool to which the VM will be added. If not set will be the value of default\_pool.<br>  tags = (Optional) Tags of the VM. Comma-separated values (e.g. tag1,tag2,tag3). Tag may only include the following characters: [a-z], [0-9] and \_. This is only meta information. If not set will be the value of default\_tags.<br>  os\_type = (Optional) Which provisioning method to use, based on the OS type. If not set will be the value of default\_os\_type.<br>  searchdomain = (Optional) Sets default DNS search domain suffix. If not set will be the value of default\_searchdomain.<br>  nameserver = (Optional) Sets default DNS server for guest. If not set will be the value of default\_nameserver.<br>  ipconfig0 = (Optional) The first IP address to assign to the guest. If not set will be the value of default\_ipconfig0.<br>  network = optional(object({<br>    model = (Optional) Network Card Model. The virtio model provides the best performance with very low CPU overhead. If not set will be the value of default\_network\_model.<br>    bridge = (Optional) Bridge to which the network device should be attached. If not set will be the value of default\_network\_bridge.<br>  }))<br>  disk = optional(object({<br>    size = (Optional) The size of the additional disk. Accepts K for kibibytes, M for mebibytes, G for gibibytes, T for tibibytes. If not set will be the value of default\_disk\_size.<br>    storage = (Optional) The name of the storage pool on which to store the disk. If not set will be the value of default\_disk\_storage.<br>    format = (Optional) The drive’s backing file’s data format. If not set will be the value of default\_disk\_format.<br>  }))<br>}))<br><br>The disk map is for an additional disk only. | <pre>map(object({<br>    name         = optional(string)<br>    target_node  = optional(string)<br>    vmid         = optional(number)<br>    desc         = optional(string)<br>    onboot       = optional(bool)<br>    boot         = optional(string)<br>    agent        = optional(number)<br>    clone        = optional(string)<br>    full_clone   = optional(bool)<br>    memory       = optional(number)<br>    sockets      = optional(number)<br>    cores        = optional(number)<br>    scsihw       = optional(string)<br>    pool         = optional(string)<br>    tags         = optional(string)<br>    os_type      = optional(string)<br>    searchdomain = optional(string)<br>    nameserver   = optional(string)<br>    ipconfig0    = optional(string)<br>    network = optional(object({<br>      model  = optional(string)<br>      bridge = optional(string)<br>    }))<br>    disk = optional(object({<br>      size    = optional(string)<br>      storage = optional(string)<br>      format  = optional(string)<br>    }))<br>  }))</pre> | <pre>{<br>  "srv1": {<br>    "ipconfig0": "ip=192.168.68.30/22,gw=192.168.68.1"<br>  },<br>  "srv2": {<br>    "ipconfig0": "ip=192.168.68.31/22,gw=192.168.68.1"<br>  },<br>  "srv3": {<br>    "ipconfig0": "ip=192.168.68.32/22,gw=192.168.68.1"<br>  }<br>}</pre> | no |
| <a name="input_pm_api_token_id"></a> [pm\_api\_token\_id](#input\_pm\_api\_token\_id) | This is an API token you have previously created for a specific user. | `string` | n/a | yes |
| <a name="input_pm_api_token_secret"></a> [pm\_api\_token\_secret](#input\_pm\_api\_token\_secret) | This uuid is only available when the token was initially created. | `string` | n/a | yes |
| <a name="input_pm_api_url"></a> [pm\_api\_url](#input\_pm\_api\_url) | This is the target Proxmox API endpoint. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agents"></a> [agents](#output\_agents) | n/a |
| <a name="output_servers"></a> [servers](#output\_servers) | n/a |
<!-- END_TF_DOCS -->

## References

- [Terraform Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [Terraform for_each](https://spacelift.io/blog/terraform-for-each)
- [Terraform for loop](https://spacelift.io/blog/terraform-for-loop)
- [Terraform tips and tricks](https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9)
