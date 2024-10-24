## provider variables ##

variable "pm_api_url" {
  type        = string
  description = "This is the target Proxmox API endpoint."
}

variable "pm_api_token_id" {
  type        = string
  description = "This is an API token you have previously created for a specific user."
  sensitive   = true
}

variable "pm_api_token_secret" {
  type        = string
  description = "This uuid is only available when the token was initially created."
  sensitive   = true
}

## Default values for optional variables ##

variable "default_target_node" {
  type        = string
  description = "The default name of the Proxmox Node on which to place the VM."
  default     = "pve1"
}

variable "default_vmid" {
  type        = number
  description = "The ID of the VM in Proxmox."
  default     = 0
}

variable "default_desc" {
  type        = string
  description = "The description of the VM."
  default     = ""
}

variable "default_onboot" {
  type        = bool
  description = "Whether to have the VM startup after the PVE node starts."
  default     = true
}

variable "default_boot" {
  type        = string
  description = "The boot order for the VM."
  default     = "order=scsi0"
}

variable "default_agent" {
  type        = number
  description = "Set to 1 to enable the QEMU Guest Agent."
  default     = 1
}

variable "default_clone" {
  type        = string
  description = "The base VM from which to clone to create the new VM."
  default     = "ubuntu-noble-tmpl"
}

variable "default_full_clone" {
  type        = bool
  description = "Set to true to create a full clone, or false to create a linked clone."
  default     = true
}

variable "default_memory" {
  type        = number
  description = "The amount of memory to allocate to the VM in Megabytes."
  default     = 2048
}

variable "default_sockets" {
  type        = number
  description = "The number of CPU sockets to allocate to the VM."
  default     = 1
}

variable "default_cores" {
  type        = number
  description = "The number of CPU cores per CPU socket to allocate to the VM."
  default     = 2
}

variable "default_scsihw" {
  type        = string
  description = "The SCSI controller to emulate."
  default     = "virtio-scsi-pci"
}

variable "default_pool" {
  type        = string
  description = "The resource pool to which the VM will be added."
  default     = ""
}

variable "default_tags" {
  type        = string
  description = "Tags of the VM."
  default     = "terraform"
}

variable "default_os_type" {
  type        = string
  description = "Which provisioning method to use, based on the OS type."
  default     = "cloud-init"
}

variable "default_searchdomain" {
  type        = string
  description = "Sets default DNS search domain suffix."
  default     = "homelab.bcochofel.com"
}

variable "default_nameserver" {
  type        = string
  description = "Sets default DNS server for guest."
  default     = "192.168.68.2"
}

variable "default_ipconfig0" {
  type        = string
  description = "The first IP address to assign to the guest. "
  default     = "ip=dhcp"
}

variable "default_network_model" {
  type        = string
  description = "Network Card Model."
  default     = "virtio"
}

variable "default_network_bridge" {
  type        = string
  description = "Bridge to which the network device should be attached."
  default     = "vmbr0"
}

variable "default_disk_format" {
  type        = string
  description = "The drive’s backing file’s data format."
  default     = "raw"
}

variable "default_disk_size" {
  type        = string
  description = "The size of the created disk, format must match the regex \\d+[GMK]"
  default     = "40G"
}

variable "default_disk_storage" {
  type        = string
  description = "The name of the storage pool on which to store the disk."
  default     = "local-lvm"
}

## K3s Servers ##

variable "k3s_server_nodes" {
  type = map(object({
    name         = optional(string)
    target_node  = optional(string)
    vmid         = optional(number)
    desc         = optional(string)
    onboot       = optional(bool)
    boot         = optional(string)
    agent        = optional(number)
    clone        = optional(string)
    full_clone   = optional(bool)
    memory       = optional(number)
    sockets      = optional(number)
    cores        = optional(number)
    scsihw       = optional(string)
    pool         = optional(string)
    tags         = optional(string)
    os_type      = optional(string)
    searchdomain = optional(string)
    nameserver   = optional(string)
    ipconfig0    = optional(string)
    network = optional(object({
      model  = optional(string)
      bridge = optional(string)
    }))
    disk = optional(object({
      size    = optional(string)
      storage = optional(string)
      format  = optional(string)
    }))
  }))
  default = {
    srv1 = {
      ipconfig0 = "ip=192.168.68.30/22,gw=192.168.68.1"
    },
    srv2 = {
      ipconfig0 = "ip=192.168.68.31/22,gw=192.168.68.1"
    },
    srv3 = {
      ipconfig0 = "ip=192.168.68.32/22,gw=192.168.68.1"
    }
  }
  description = <<-EOT
  A map of K3s Server Nodes to be created.
  map(object({
    name = (Optional) The name of the VM within Proxmox. If not set will be generated.
    target_node = (Optional) The name of the Proxmox Node on which to place the VM. If not set will be the value of the default_target_node.
    vmid = (Optional) The ID of the VM in Proxmox. If not set will be the value of default_vmid.
    desc = (Optional) The description of the VM. Shows as the 'Notes' field in the Proxmox GUI. If not set will be the value of default_desc.
    onboot = (Optional) Whether to have the VM startup after the PVE node starts. If not set will be the value of default_onboot.
    boot = (Optional) The boot order for the VM. For example: order=scsi0;ide2;net0. If not set will be the value of default_boot.
    agent = (Optional) Set to 1 to enable the QEMU Guest Agent. Note, you must run the qemu-guest-agent daemon in the guest for this to have any effect. If not set will be the value of default_agent.
    clone = (Optional) The base VM from which to clone to create the new VM. If not set will be the value of default_clone.
    full_clone = (Optional) Set to true to create a full clone, or false to create a linked clone. If not set will be the value of default_full_clone.
    memory = (Optional) The amount of memory to allocate to the VM in Megabytes. If not set will be the value of default_memory.
    sockets = (Optional) The number of CPU sockets to allocate to the VM. If not set will be the value of default_sockets.
    cores = (Optional) The number of CPU cores per CPU socket to allocate to the VM. If not set will be the value of default_cores.
    scsihw = (Optional) The SCSI controller to emulate. If not set will be the value of default_scsihw.
    pool = (Optional) The resource pool to which the VM will be added. If not set will be the value of default_pool.
    tags = (Optional) Tags of the VM. Comma-separated values (e.g. tag1,tag2,tag3). Tag may only include the following characters: [a-z], [0-9] and _. This is only meta information. If not set will be the value of default_tags.
    os_type = (Optional) Which provisioning method to use, based on the OS type. If not set will be the value of default_os_type.
    searchdomain = (Optional) Sets default DNS search domain suffix. If not set will be the value of default_searchdomain.
    nameserver = (Optional) Sets default DNS server for guest. If not set will be the value of default_nameserver.
    ipconfig0 = (Optional) The first IP address to assign to the guest. If not set will be the value of default_ipconfig0.
    network = optional(object({
      model = (Optional) Network Card Model. The virtio model provides the best performance with very low CPU overhead. If not set will be the value of default_network_model.
      bridge = (Optional) Bridge to which the network device should be attached. If not set will be the value of default_network_bridge.
    }))
    disk = optional(object({
      size = (Optional) The size of the additional disk. Accepts K for kibibytes, M for mebibytes, G for gibibytes, T for tibibytes. If not set will be the value of default_disk_size.
      storage = (Optional) The name of the storage pool on which to store the disk. If not set will be the value of default_disk_storage.
      format = (Optional) The drive’s backing file’s data format. If not set will be the value of default_disk_format.
    }))
  }))

  The disk map is for an additional disk only.
  EOT
}


## K3s Agents ##

variable "k3s_agent_nodes" {
  type = map(object({
    name         = optional(string)
    target_node  = optional(string)
    vmid         = optional(number)
    desc         = optional(string)
    onboot       = optional(bool)
    boot         = optional(string)
    agent        = optional(number)
    clone        = optional(string)
    full_clone   = optional(bool)
    memory       = optional(number)
    sockets      = optional(number)
    cores        = optional(number)
    scsihw       = optional(string)
    pool         = optional(string)
    tags         = optional(string)
    os_type      = optional(string)
    searchdomain = optional(string)
    nameserver   = optional(string)
    ipconfig0    = optional(string)
    network = optional(object({
      model  = optional(string)
      bridge = optional(string)
    }))
    disk = optional(object({
      size    = optional(string)
      storage = optional(string)
      format  = optional(string)
    }))
  }))
  default = {
    agent1 = {
      ipconfig0 = "ip=192.168.68.40/22,gw=192.168.68.1"
    },
    agent2 = {
      ipconfig0 = "ip=192.168.68.41/22,gw=192.168.68.1"
    },
    agent3 = {
      ipconfig0 = "ip=192.168.68.42/22,gw=192.168.68.1"
    }
  }
  description = <<-EOT
  A map of K3s Agent Nodes to be created.
  map(object({
    name = (Optional) The name of the VM within Proxmox. If not set will be generated.
    target_node = (Optional) The name of the Proxmox Node on which to place the VM. If not set will be the value of the default_target_node.
    vmid = (Optional) The ID of the VM in Proxmox. If not set will be the value of default_vmid.
    desc = (Optional) The description of the VM. Shows as the 'Notes' field in the Proxmox GUI. If not set will be the value of default_desc.
    onboot = (Optional) Whether to have the VM startup after the PVE node starts. If not set will be the value of default_onboot.
    boot = (Optional) The boot order for the VM. For example: order=scsi0;ide2;net0. If not set will be the value of default_boot.
    agent = (Optional) Set to 1 to enable the QEMU Guest Agent. Note, you must run the qemu-guest-agent daemon in the guest for this to have any effect. If not set will be the value of default_agent.
    clone = (Optional) The base VM from which to clone to create the new VM. If not set will be the value of default_clone.
    full_clone = (Optional) Set to true to create a full clone, or false to create a linked clone. If not set will be the value of default_full_clone.
    memory = (Optional) The amount of memory to allocate to the VM in Megabytes. If not set will be the value of default_memory.
    sockets = (Optional) The number of CPU sockets to allocate to the VM. If not set will be the value of default_sockets.
    cores = (Optional) The number of CPU cores per CPU socket to allocate to the VM. If not set will be the value of default_cores.
    scsihw = (Optional) The SCSI controller to emulate. If not set will be the value of default_scsihw.
    pool = (Optional) The resource pool to which the VM will be added. If not set will be the value of default_pool.
    tags = (Optional) Tags of the VM. Comma-separated values (e.g. tag1,tag2,tag3). Tag may only include the following characters: [a-z], [0-9] and _. This is only meta information. If not set will be the value of default_tags.
    os_type = (Optional) Which provisioning method to use, based on the OS type. If not set will be the value of default_os_type.
    searchdomain = (Optional) Sets default DNS search domain suffix. If not set will be the value of default_searchdomain.
    nameserver = (Optional) Sets default DNS server for guest. If not set will be the value of default_nameserver.
    ipconfig0 = (Optional) The first IP address to assign to the guest. If not set will be the value of default_ipconfig0.
    network = optional(object({
      model = (Optional) Network Card Model. The virtio model provides the best performance with very low CPU overhead. If not set will be the value of default_network_model.
      bridge = (Optional) Bridge to which the network device should be attached. If not set will be the value of default_network_bridge.
    }))
    disk = optional(object({
      size = (Optional) The size of the additional disk. Accepts K for kibibytes, M for mebibytes, G for gibibytes, T for tibibytes. If not set will be the value of default_disk_size.
      storage = (Optional) The name of the storage pool on which to store the disk. If not set will be the value of default_disk_storage.
      format = (Optional) The drive’s backing file’s data format. If not set will be the value of default_disk_format.
    }))
  }))

  The disk map is for an additional disk only.
  EOT
}
