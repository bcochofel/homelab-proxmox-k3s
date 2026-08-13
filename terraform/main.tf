# ----------------------------------------------------------------------------
# K3s cluster on Proxmox.
# Packer template -> Terraform clones N+M VMs -> generates Ansible inventory.
# ----------------------------------------------------------------------------

# Look up the template's VMID by name so tfvars can reference it by name.
data "proxmox_virtual_environment_vms" "template" {
  node_name = var.target_node

  filter {
    name   = "name"
    values = [var.vm_template]
  }
}

locals {
  template_vmid = one(data.proxmox_virtual_environment_vms.template.vms).vm_id
}

# K3s server (control-plane) nodes
module "k3s_server" {
  source   = "./modules/vm"
  for_each = { for n in var.k3s_server_nodes : n.name => n }

  name          = each.value.name
  vmid          = each.value.vmid
  target_node   = var.target_node
  template_vmid = local.template_vmid

  cores  = each.value.cores
  memory = each.value.memory
  disk   = each.value.disk

  ip_cidr        = each.value.ip_cidr
  gateway        = var.gateway
  network_bridge = var.network_bridge
  nameserver     = var.nameserver
  searchdomain   = var.searchdomain

  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.sshkeys

  tags = ["terraform", "k3s", "k3s-server"]
}

# K3s agent (worker) nodes
module "k3s_agent" {
  source   = "./modules/vm"
  for_each = { for n in var.k3s_agent_nodes : n.name => n }

  name          = each.value.name
  vmid          = each.value.vmid
  target_node   = var.target_node
  template_vmid = local.template_vmid

  cores  = each.value.cores
  memory = each.value.memory
  disk   = each.value.disk

  ip_cidr        = each.value.ip_cidr
  gateway        = var.gateway
  network_bridge = var.network_bridge
  nameserver     = var.nameserver
  searchdomain   = var.searchdomain

  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.sshkeys

  tags = ["terraform", "k3s", "k3s-agent"]
}

# ----------------------------------------------------------------------------
# Generate Ansible inventory.
# Only hosts.ini is generated — group_vars/ stays hand-authored so Terraform
# never clobbers tuning.
# ----------------------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.root}/templates/inventory.ini.tftpl", {
    servers      = { for k, v in module.k3s_server : k => v },
    agents       = { for k, v in module.k3s_agent : k => v },
    ansible_user = var.ansible_user
  })
  filename = "${path.root}/../ansible/inventory/hosts.ini"
}
