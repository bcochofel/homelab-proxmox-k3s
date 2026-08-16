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
    name       = string
    vmid       = optional(number) # omitted -> Proxmox auto-assigns the next available ID
    ip_cidr    = string           # e.g. 192.168.68.40/22
    cores      = number
    memory     = number           # MB
    disk       = number           # GB
    extra_disk = optional(number) # GB, blank second disk at scsi1
  }))
  description = "K3s server (control-plane) node definitions"
  default = [
    # 4 vCPU / 8GB, not the original 2/4 — the control-plane node also
    # carries Cilium's operator/envoy/hubble-relay/hubble-ui on top of
    # K3s server + Traefik + ArgoCD, and while agents were briefly stuck
    # off the cluster the full otel-demo chart landed on this node alone
    # and pegged it (load average ~25 on 2 vCPU, memory nearly exhausted).
    # First bumped to 4/6 — confirmed live afterward that CPU settled to
    # ~30%, but memory still sat around ~76% of the 6GB (4.6GB used) once
    # otel-demo redistributed, so bumped again to 8GB for real headroom.
    # pve1 has ample spare CPU (~2 of 16 physical cores actually in use
    # cluster-wide when this was first sized) and enough unallocated RAM.
    #
    # extra_disk (50GB, scsi1) added after k3s-srv1 hit kubelet
    # DiskPressure — the Packer template's LVM layout only gives `/`
    # (where /var/lib/rancher/k3s and /var/lib/kubelet live) 25GB of the
    # 50GB template disk, splitting the rest into home/tmp/opt this
    # workload barely touches. The new disk gets added to the existing
    # volume group and root extended onto it (see TODO.md) rather than
    # reshuffling the existing LVs live. All three nodes get one, since
    # agent1/agent2 were already trending the same direction.
    { name = "k3s-srv1", ip_cidr = "192.168.68.40/22", cores = 4, memory = 8192, disk = 50, extra_disk = 50 },
  ]
}

variable "k3s_agent_nodes" {
  type = list(object({
    name       = string
    vmid       = optional(number) # omitted -> Proxmox auto-assigns the next available ID
    ip_cidr    = string
    cores      = number
    memory     = number
    disk       = number
    extra_disk = optional(number)
  }))
  description = "K3s agent (worker) node definitions"
  default = [
    { name = "k3s-agent1", ip_cidr = "192.168.68.41/22", cores = 2, memory = 4096, disk = 50, extra_disk = 50 },
    { name = "k3s-agent2", ip_cidr = "192.168.68.42/22", cores = 2, memory = 4096, disk = 50, extra_disk = 50 },
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
  description = "DNS nameservers for cloud-init, in order — CoreDNS primary (192.168.68.2) then CoreDNS secondary (192.168.68.3, AXFR-synced, runs on the user's QNAP NAS outside this repo), for redundancy. Interim: once Pihole primary (on the core repo's dns VM) and Pihole secondary (Raspberry Pi 3, 192.168.68.6) are configured to forward to CoreDNS and do ad-blocking only, this moves to the Pihole pair instead"
  default     = ["192.168.68.2", "192.168.68.3"]
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
