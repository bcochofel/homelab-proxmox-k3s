provider "proxmox" {
  # Configuration options
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret

  #pm_tls_insecure = true
}

## K3s Servers ##

resource "random_pet" "server_name" {
  for_each = var.k3s_server_nodes
}

resource "proxmox_vm_qemu" "servers" {
  for_each = var.k3s_server_nodes

  name        = lookup(each.value, "name", random_pet.server_name[each.key].id)
  target_node = lookup(each.value, "target_node", var.default_target_node)
  vmid        = lookup(each.value, "vmid", var.default_vmid)
  desc        = lookup(each.value, "desc", var.default_desc)
  onboot      = lookup(each.value, "onboot", var.default_onboot)
  boot        = lookup(each.value, "boot", var.default_boot)

  agent        = lookup(each.value, "agent", var.default_agent)
  clone        = lookup(each.value, "clone", var.default_clone)
  full_clone   = lookup(each.value, "full_clone", var.default_full_clone)
  memory       = lookup(each.value, "memory", var.default_memory)
  sockets      = lookup(each.value, "sockets", var.default_sockets)
  cores        = lookup(each.value, "cores", var.default_cores)
  scsihw       = lookup(each.value, "scsihw", var.default_scsihw)
  pool         = lookup(each.value, "pool", var.default_pool)
  tags         = lookup(each.value, "tags", var.default_tags)
  os_type      = lookup(each.value, "os_type", var.default_os_type)
  searchdomain = lookup(each.value, "searchdomain", var.default_searchdomain)
  nameserver   = lookup(each.value, "nameserver", var.default_nameserver)
  ipconfig0    = lookup(each.value, "ipconfig0", var.default_ipconfig0)

  network {
    model  = try(each.value.network.model, var.default_network_model)
    bridge = try(each.value.network.bridge, var.default_network_bridge)
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
          size    = try(each.value.disk.size, var.default_disk_size)
          storage = try(each.value.disk.storage, var.default_disk_storage)
          format  = try(each.value.disk.format, var.default_disk_format)
        }
      }
    }
  }
}

## K3s Agents ##

resource "random_pet" "agent_name" {
  for_each = var.k3s_agent_nodes
}

resource "proxmox_vm_qemu" "agents" {
  for_each = var.k3s_agent_nodes

  name        = lookup(each.value, "name", random_pet.agent_name[each.key].id)
  target_node = lookup(each.value, "target_node", var.default_target_node)
  vmid        = lookup(each.value, "vmid", var.default_vmid)
  desc        = lookup(each.value, "desc", var.default_desc)
  onboot      = lookup(each.value, "onboot", var.default_onboot)
  boot        = lookup(each.value, "boot", var.default_boot)

  agent        = lookup(each.value, "agent", var.default_agent)
  clone        = lookup(each.value, "clone", var.default_clone)
  full_clone   = lookup(each.value, "full_clone", var.default_full_clone)
  memory       = lookup(each.value, "memory", var.default_memory)
  sockets      = lookup(each.value, "sockets", var.default_sockets)
  cores        = lookup(each.value, "cores", var.default_cores)
  scsihw       = lookup(each.value, "scsihw", var.default_scsihw)
  pool         = lookup(each.value, "pool", var.default_pool)
  tags         = lookup(each.value, "tags", var.default_tags)
  os_type      = lookup(each.value, "os_type", var.default_os_type)
  searchdomain = lookup(each.value, "searchdomain", var.default_searchdomain)
  nameserver   = lookup(each.value, "nameserver", var.default_nameserver)
  ipconfig0    = lookup(each.value, "ipconfig0", var.default_ipconfig0)

  network {
    model  = try(each.value.network.model, var.default_network_model)
    bridge = try(each.value.network.bridge, var.default_network_bridge)
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
          size    = try(each.value.disk.size, var.default_disk_size)
          storage = try(each.value.disk.storage, var.default_disk_storage)
          format  = try(each.value.disk.format, var.default_disk_format)
        }
      }
    }
  }
}
