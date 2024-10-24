provider "proxmox" {
  # Configuration options
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret

  #pm_tls_insecure = true
}

## K3s Servers ##

resource "random_pet" "server_name" {
  for_each = local.servers
}

resource "proxmox_vm_qemu" "servers" {
  for_each = local.servers

  name         = each.value.name != null ? each.value.name : random_pet.server_name[each.key].id
  target_node  = each.value.target_node
  vmid         = each.value.vmid
  desc         = each.value.desc
  onboot       = each.value.onboot
  boot         = each.value.boot
  agent        = each.value.agent
  clone        = each.value.clone
  full_clone   = each.value.full_clone
  memory       = each.value.memory
  sockets      = each.value.sockets
  cores        = each.value.cores
  scsihw       = each.value.scsihw
  pool         = each.value.pool
  tags         = each.value.tags
  os_type      = each.value.os_type
  searchdomain = each.value.searchdomain
  nameserver   = each.value.nameserver
  ipconfig0    = each.value.ipconfig0

  network {
    model  = each.value.network.model
    bridge = each.value.network.bridge
  }

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = "12G"
          storage = "local-lvm"
          format  = "raw"
        }
      }
      scsi1 {
        disk {
          size    = each.value.disk.size
          storage = each.value.disk.storage
          format  = each.value.disk.format
        }
      }
    }
  }
}

## K3s Agents ##

resource "random_pet" "agent_name" {
  for_each = local.agents
}

resource "proxmox_vm_qemu" "agents" {
  for_each = local.agents

  name         = each.value.name != null ? each.value.name : random_pet.agent_name[each.key].id
  target_node  = each.value.target_node
  vmid         = each.value.vmid
  desc         = each.value.desc
  onboot       = each.value.onboot
  boot         = each.value.boot
  agent        = each.value.agent
  clone        = each.value.clone
  full_clone   = each.value.full_clone
  memory       = each.value.memory
  sockets      = each.value.sockets
  cores        = each.value.cores
  scsihw       = each.value.scsihw
  pool         = each.value.pool
  tags         = each.value.tags
  os_type      = each.value.os_type
  searchdomain = each.value.searchdomain
  nameserver   = each.value.nameserver
  ipconfig0    = each.value.ipconfig0

  network {
    model  = each.value.network.model
    bridge = each.value.network.bridge
  }

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = "12G"
          storage = "local-lvm"
          format  = "raw"
        }
      }
      scsi1 {
        disk {
          size    = each.value.disk.size
          storage = each.value.disk.storage
          format  = each.value.disk.format
        }
      }
    }
  }
}

# generate ansible inventory file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.root}/templates/inventory.tftpl", {
    servers_ips = flatten([
      for srv_key, srv in resource.proxmox_vm_qemu.servers : [
        split("=", split("/", srv.ipconfig0)[0])[1]
      ]
    ]),
    agents_ips = flatten([
      for srv_key, srv in resource.proxmox_vm_qemu.agents : [
        split("=", split("/", srv.ipconfig0)[0])[1]
      ]
    ])
  })
  filename        = "${path.root}/../ansible/inventory"
  file_permission = "0640"
}
