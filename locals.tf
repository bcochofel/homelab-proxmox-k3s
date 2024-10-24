locals {
  servers = {
    for k, v in var.k3s_server_nodes :
    k => {
      name         = v.name
      target_node  = v.target_node != null ? v.target_node : var.default_target_node
      vmid         = v.vmid != null ? v.vmid : var.default_vmid
      desc         = v.desc != null ? v.desc : var.default_desc
      onboot       = v.onboot != null ? v.onboot : var.default_onboot
      boot         = v.boot != null ? v.boot : var.default_boot
      agent        = v.agent != null ? v.agent : var.default_agent
      clone        = v.clone != null ? v.clone : var.default_clone
      full_clone   = v.full_clone != null ? v.full_clone : var.default_full_clone
      memory       = v.memory != null ? v.memory : var.default_memory
      sockets      = v.sockets != null ? v.sockets : var.default_sockets
      cores        = v.cores != null ? v.cores : var.default_cores
      scsihw       = v.scsihw != null ? v.scsihw : var.default_scsihw
      pool         = v.pool != null ? v.pool : var.default_pool
      tags         = v.tags != null ? v.tags : var.default_tags
      os_type      = v.os_type != null ? v.os_type : var.default_os_type
      searchdomain = v.searchdomain != null ? v.searchdomain : var.default_searchdomain
      nameserver   = v.nameserver != null ? v.nameserver : var.default_nameserver
      ipconfig0    = v.ipconfig0 != null ? v.ipconfig0 : var.default_ipconfig0
      network = {
        model  = try(v.network.model, var.default_network_model)
        bridge = try(v.network.bridge, var.default_network_bridge)
      }
      disk = {
        size    = try(v.disk.size, var.default_disk_size)
        storage = try(v.disk.storage, var.default_disk_storage)
        format  = try(v.disk.format, var.default_disk_format)
      }
    }
  }
  agents = {
    for k, v in var.k3s_agent_nodes :
    k => {
      name         = v.name
      target_node  = v.target_node != null ? v.target_node : var.default_target_node
      vmid         = v.vmid != null ? v.vmid : var.default_vmid
      desc         = v.desc != null ? v.desc : var.default_desc
      onboot       = v.onboot != null ? v.onboot : var.default_onboot
      boot         = v.boot != null ? v.boot : var.default_boot
      agent        = v.agent != null ? v.agent : var.default_agent
      clone        = v.clone != null ? v.clone : var.default_clone
      full_clone   = v.full_clone != null ? v.full_clone : var.default_full_clone
      memory       = v.memory != null ? v.memory : var.default_memory
      sockets      = v.sockets != null ? v.sockets : var.default_sockets
      cores        = v.cores != null ? v.cores : var.default_cores
      scsihw       = v.scsihw != null ? v.scsihw : var.default_scsihw
      pool         = v.pool != null ? v.pool : var.default_pool
      tags         = v.tags != null ? v.tags : var.default_tags
      os_type      = v.os_type != null ? v.os_type : var.default_os_type
      searchdomain = v.searchdomain != null ? v.searchdomain : var.default_searchdomain
      nameserver   = v.nameserver != null ? v.nameserver : var.default_nameserver
      ipconfig0    = v.ipconfig0 != null ? v.ipconfig0 : var.default_ipconfig0
      network = {
        model  = try(v.network.model, var.default_network_model)
        bridge = try(v.network.bridge, var.default_network_bridge)
      }
      disk = {
        size    = try(v.disk.size, var.default_disk_size)
        storage = try(v.disk.storage, var.default_disk_storage)
        format  = try(v.disk.format, var.default_disk_format)
      }
    }
  }
}
