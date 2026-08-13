# --------------------------------------------------------
# Proxmox connection (bpg/proxmox)
# --------------------------------------------------------
variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint, e.g. https://192.168.68.20:8006/"
}

variable "proxmox_api_token" {
  type        = string
  description = "API token, form user@realm!tokenid=secret"
  sensitive   = true
}

variable "proxmox_insecure" {
  type        = bool
  description = "Skip TLS verification (homelab self-signed cert)"
  default     = true
}

variable "proxmox_ssh_username" {
  type        = string
  description = "SSH username for provider operations that require SSH"
  default     = "root"
}

variable "target_node" {
  type        = string
  description = "Proxmox node name to place VMs on"
  default     = "pve1"
}

variable "vm_template" {
  type        = string
  description = "Name of the Packer-built template to clone"
  default     = "ubuntu-26.04-k3s"
}

# --------------------------------------------------------
# K3s cluster topology
# --------------------------------------------------------
variable "k3s_server_nodes" {
  type = list(object({
    name    = string
    vmid    = number
    ip_cidr = string # e.g. 192.168.68.25/22
    cores   = number
    memory  = number # MB
    disk    = number # GB
  }))
  description = "K3s server (control-plane) node definitions"
  default = [
    { name = "k3s-srv1", vmid = 9550, ip_cidr = "192.168.68.25/22", cores = 2, memory = 4096, disk = 50 },
  ]
}

variable "k3s_agent_nodes" {
  type = list(object({
    name    = string
    vmid    = number
    ip_cidr = string
    cores   = number
    memory  = number
    disk    = number
  }))
  description = "K3s agent (worker) node definitions"
  default = [
    { name = "k3s-agent1", vmid = 9551, ip_cidr = "192.168.68.26/22", cores = 2, memory = 4096, disk = 50 },
    { name = "k3s-agent2", vmid = 9552, ip_cidr = "192.168.68.27/22", cores = 2, memory = 4096, disk = 50 },
  ]
}

# --------------------------------------------------------
# Networking
# --------------------------------------------------------
variable "gateway" {
  type        = string
  description = "Network gateway"
  default     = "192.168.68.1"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

variable "nameserver" {
  type        = list(string)
  description = "DNS nameservers for cloud-init, in order (CoreDNS + Pihole — both, for redundancy)"
  default     = ["192.168.68.42", "192.168.68.43"]
}

variable "searchdomain" {
  type        = string
  description = "DNS search domain"
  default     = "homelab.bcochofel.com"
}

# --------------------------------------------------------
# cloud-init
# --------------------------------------------------------
variable "ciuser" {
  type        = string
  description = "cloud-init user (matches Packer template default user)"
  default     = "ubuntu"
}

variable "cipassword" {
  type        = string
  description = "cloud-init user password"
  sensitive   = true
}

variable "sshkeys" {
  type        = string
  description = "Newline-delimited SSH public keys for the cloud-init user"
}

# --------------------------------------------------------
# Ansible inventory generation
# --------------------------------------------------------
variable "ansible_user" {
  type        = string
  description = "Remote user Ansible connects as (matches ansible.cfg)"
  default     = "ubuntu"
}
