# Copy to terraform.tfvars (gitignored) or set as HCP workspace variables.

proxmox_endpoint = "https://192.168.68.20:8006/"
# Set TF_VAR_proxmox_api_token in env / HCP (sensitive):
#   terraform@pve!tf=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
proxmox_insecure = true
target_node      = "pve1"

vm_template = "ubuntu-26.04-k3s"

gateway        = "192.168.68.1"
network_bridge = "vmbr0"
nameserver     = ["192.168.68.2", "192.168.68.3"]
searchdomain   = "homelab.bcochofel.com"

ciuser = "ubuntu"
# Set TF_VAR_cipassword in env / HCP (sensitive)
sshkeys = "ssh-ed25519 AAAA... bcochofel@host"

ansible_user = "ubuntu"

# Defaults already size k3s-srv1 (2 vCPU / 4 GB / 40 GB, 192.168.68.40) and
# k3s-agent1/k3s-agent2 (2 vCPU / 4 GB / 40 GB, 192.168.68.41-.42) — sized against
# pve1's live capacity (16 vCPU / 62.5 GB, ~13 vCPU / 35 GB already
# allocated to the core/elastic VMs). vmid is left unset in the defaults —
# Proxmox auto-assigns the next available ID. Override k3s_server_nodes/
# k3s_agent_nodes here only if you want different VMIDs, IPs, sizing, or
# node counts (e.g. a 3-server HA control plane).
