# Terraform — K3s cluster VMs on Proxmox (bpg/proxmox)

Clones the Packer template (`ubuntu-26.04-k3s`) into a K3s server node and
two K3s agent nodes, assigns each a static IP via cloud-init, and generates
`../ansible/inventory/hosts.ini`.

| VM | Role | IP | Ansible group |
| --- | --- | --- | --- |
| k3s-srv1 | K3s server (control-plane) | 192.168.68.25 | `k3s_server` |
| k3s-agent1 | K3s agent (worker) | 192.168.68.26 | `k3s_agent` |
| k3s-agent2 | K3s agent (worker) | 192.168.68.27 | `k3s_agent` |

Sizing (2 vCPU / 4 GB / 50 GB each) was picked against `pve1`'s live
capacity, not a round number — see `CLAUDE.md`'s "Decisions that are
deliberate" for the math (16 vCPU / 62.5 GB total, ~13 vCPU / 35 GB already
allocated to the core/elastic repos' VMs before this cluster exists). Disk
is pinned at 50 GB, not lower, because the bpg provider can't shrink a
cloned disk below the `ubuntu-26.04-k3s` template's own disk size.
Single-server topology today, no HA embedded-etcd — see the same section
for what growing to 3 servers would change.

- `modules/vm/` — the same reusable single-VM clone module the sibling
  `homelab-proxmox-core`/`homelab-proxmox-elastic` repos use, with **one
  local change**: `nameserver` is `list(string)` here instead of a single
  string, because this repo's VMs get both `192.168.68.42` (CoreDNS) *and*
  `192.168.68.43` (Pihole) for resolver redundancy, not just one. Otherwise
  copied as-is — it takes no other workload-specific inputs, role differs
  only in the `tags` passed in and which Ansible group the node lands in.
- `k3s_server_nodes` / `k3s_agent_nodes` (`variables.tf`) are `list(object(...))`
  — same for-each-over-a-list idiom as elastic's `es_nodes` — so growing
  the cluster (more agents, or a 3-server HA control plane) is adding
  entries to a list, not hand-writing new `module` blocks.
- `templates/inventory.ini.tftpl` — renders the Ansible inventory (INI
  format): `[k3s_server]`, `[k3s_agent]`, and a `[k3s:children]` group so
  Ansible roles can target the whole cluster in one play.
- State: HCP Terraform workspace `k3s-cluster` (state only — Execution Mode
  is Local, since Proxmox is LAN-only and HCP's infra can't reach it).

Decoupled from Ansible by design — run `terraform apply`, then the Ansible
playbooks separately (no `local-exec` chaining).

Always `terraform plan` and review the output before applying; never
`destroy`.

## Configuration: `example.tfvars` vs `terraform.tfvars` vs secrets

Three different places feed this module's inputs, split by sensitivity:

- **`example.tfvars`** — committed to git. The root `.gitignore` blanket-
  ignores `*.tfvars`, then explicitly re-includes this one file
  (`!example.tfvars`), so it's the one `.tfvars` that's actually meant to be
  checked in. It's a template with realistic placeholder values for every
  *non-secret* input (`target_node`, `vm_template`, `gateway`,
  `network_bridge`, `nameserver`, `searchdomain`, `ciuser`, `ansible_user`,
  an example `sshkeys` value) plus the `k3s_server_nodes`/`k3s_agent_nodes`
  default shapes. Never put a real secret in it — edit it only to change
  the example values everyone starts from.
- **`terraform.tfvars`** — what you actually run against. Gitignored
  (`terraform/terraform.tfvars` is listed explicitly, on top of the
  blanket `*.tfvars` rule). Create it once with
  `cp example.tfvars terraform.tfvars`, then fill in your real
  `target_node` and a real `sshkeys` value (not the placeholder), plus any
  `k3s_server_nodes`/`k3s_agent_nodes` override you need. `sshkeys` is the
  one Terraform input in this module that's *not* marked `sensitive` in
  `variables.tf` — that's exactly why it belongs here rather than
  `secrets.yaml`/`.envrc`: it's a public key, there's nothing to encrypt.
- **`secrets.yaml` + `terraform/.envrc`** — everything Terraform treats as
  `sensitive` (`proxmox_api_token`, `cipassword`), plus the unrelated
  Terraform Cloud auth token (`TF_TOKEN_app_terraform_io`, read by the
  Terraform CLI itself, not by any `var.*`). These never touch a `.tfvars`
  file — they arrive purely as `TF_VAR_*` env vars via direnv.

Terraform picks up `terraform.tfvars` and `TF_VAR_*` env vars automatically
— no `-var-file` flag needed, just run `terraform plan`/`apply` from
`terraform/`.

## Proxmox user & API token

Terraform authenticates as its own Proxmox user/token, separate from the
Packer token (see `CLAUDE.md`'s "Proxmox auth" section) — least privilege
per tool. Current token id: `terraform@pve!terraform-automation` (matching
Packer's `packer@pve!packer-automation` naming convention — the same
Proxmox-node-level users the core/elastic repos already created; this repo
doesn't need its own separate `pveum` user, just its own API token secret
value recorded in this repo's own `secrets.yaml`).

`pveum` only exists on the Proxmox node itself — see
[`docs/PACKER.md`](PACKER.md#proxmox-user--api-token) for the three ways to
run it (SSH into the node, the web UI's Datacenter -> Permissions, or the
node's own web Shell); the same options apply here.

```bash
# 1. Role scoped to what Terraform actually does: clone the Packer
#    template, size/network/cloud-init the clone, and read template/VM
#    state. Not building or templating — that's Packer's job.
pveum role add TerraformRole -privs "VM.Allocate,VM.Audit,VM.Clone,\
VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,\
VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,\
VM.Monitor,VM.PowerMgmt,Datastore.Allocate,Datastore.AllocateSpace,\
Datastore.Audit,SDN.Use"

# 2. User for the role (no password; auth is via API token only)
pveum user add terraform@pve --comment "Terraform VM clone/configure"
pveum aclmod / -user terraform@pve -role TerraformRole

# 3. API token. --privsep 0: the token inherits the user's ACL directly.
pveum user token add terraform@pve terraform-automation --privsep 0
```

If `terraform@pve` already exists (created by the core or elastic repo),
skip straight to minting a new token for this repo — one Proxmox user can
hold multiple tokens, and each repo should use its own token value even
when the user/role is shared, so a leaked/rotated token in one repo's
`secrets.yaml` doesn't affect the others.

The token-add command prints the token secret once — it is not retrievable
again. Put `terraform@pve!terraform-automation` (or whatever id you minted)
and the printed secret into this repo's `secrets.yaml` (SOPS-encrypted) so
`terraform/.envrc` can export `TF_VAR_proxmox_api_token` in the combined
`user@realm!tokenid=secret` form `variables.tf` expects:

```bash
export TF_VAR_proxmox_endpoint="${PROXMOX_ENDPOINT}"
export TF_VAR_proxmox_api_token="${proxmox_terraform_token_id}=${proxmox_terraform_token_secret}"
export TF_VAR_cipassword="${cloudinit_password}"
```

(`proxmox_terraform_token_id`/`_secret` and `cloudinit_password` are the
`secrets.yaml` keys — a split id/secret pair, matching Packer's
`proxmox_packer_token_id`/`_secret` convention, rather than one combined
value.)

| Privilege | Why Terraform needs it |
| --- | --- |
| `VM.Allocate` | Required on the *destination* VMID for a clone, not just fresh-built VMs — Proxmox's clone endpoint checks `VM.Clone` on the source template but `VM.Allocate` on the new VMID, since claiming a not-yet-existing VM ID is an "allocate" regardless of whether the VM ends up empty or cloned. |
| `VM.Audit` | Look up the template's VMID by name (`data.proxmox_virtual_environment_vms.template`), read VM state while polling for the cloud-init-assigned IP |
| `VM.Clone` | Read/export permission on the *source* template |
| `VM.Config.CDROM` | If the `ubuntu-26.04-k3s` template carries a leftover `ide`-bus slot from the Packer build, bpg's `initialization` block reconfigures the cloud-init drive on that same bus on every clone, which Proxmox checks under the CD-ROM permission bucket regardless of actual media type — same incident the core/elastic repos hit, granted here preemptively. |
| `VM.Config.CPU`, `VM.Config.Memory`, `VM.Config.Disk`, `VM.Config.HWType`, `VM.Config.Network` | Set cores, memory, resize the cloned disk, attach the network device |
| `VM.Config.Cloudinit` | Write the static IP/gateway, DNS, and cloud-init user-account config the clone boots with |
| `VM.Config.Options` | Set description/tags on the clone |
| `VM.Monitor`, `VM.PowerMgmt` | Start the clone and poll the QEMU guest agent until it reports an IP |
| `Datastore.Allocate`, `Datastore.AllocateSpace` | Allocate the cloned VM's disk + cloud-init drive on `datastore_id` |
| `Datastore.Audit` | Read storage info |
| `SDN.Use` | Attach the VM's NIC to `vmbr0` — same reason Packer needs it: required once the bridge is managed as an SDN zone |

Not granted: anything from Packer's role that's about *building* a template
from an ISO (`VM.Console`, `Datastore.AllocateTemplate`, `Sys.Modify`) —
Terraform only ever clones an already-built template, it never creates one.

`providers.tf`'s `ssh { agent = true, username = var.proxmox_ssh_username }`
block is configured but not currently exercised — this repo's cloud-init
only sets IP/DNS/user-account via the API (`initialization` block), no
custom snippet/file upload.

## Security checks and policy enforcement

Terraform under `terraform/` is scanned by TFLint, Trivy, and Checkov (see
[`CONTRIBUTING.md`](../CONTRIBUTING.md)'s pre-commit section). Trivy and
Checkov ship no built-in checks for the `bpg/proxmox` provider — Aqua's
check database (`avd.aquasec.com`) has no Proxmox category (nor a VMware
one, for what it's worth), so anything Proxmox-specific has to be a custom
check. Custom policies live under `policies/` (copied verbatim from the
sibling `homelab-proxmox-core`/`homelab-proxmox-elastic` repos, which wrote
and verified them first):

- `policies/checkov/proxmox_*.yaml` — one file per check, targeting
  `proxmox_virtual_environment_vm`: UEFI firmware (`bios = "ovmf"`,
  MEDIUM), the QEMU guest agent enabled (MEDIUM), a `description` set
  (LOW), and the modern `q35` machine type (LOW). `checkov.yaml`'s
  `check: [MEDIUM, HIGH, CRITICAL]` genuinely filters which checks run —
  despite checkov's own "Filtering checks by severity is only possible
  with an API key" log line, that's confirmed (in the elastic repo) to be
  misleading for custom checks: a check with no `severity` (or one below
  the configured floor) in its metadata is silently excluded, not merely
  unfiltered. The two LOW checks here (description, machine type) are
  intentionally not enforced as a result. `CKV_PROXMOX_1` (UEFI) is a real,
  unaddressed gap — `bios` isn't set to `"ovmf"` in `modules/vm/main.tf` —
  and is deliberately skip-listed in `checkov.yaml` for now. Remove the
  skip once the module sets `bios = "ovmf"` (and, per `PROXMOX-004`, an
  `efi_disk` block).
- `policies/trivy/proxmox_*.rego` — the same intent, written as Trivy custom
  Rego checks (one package per file), plus two provider-level checks (no
  hardcoded `api_token`, no `insecure = true`). **Caveat, carried over from
  the core/elastic repos:** custom Rego checks could not be confirmed to
  actually fire against Trivy via the documented
  `--config-check`/`--check-namespaces`/`--raw-config-scanners` flags — even
  a trivial always-true test policy produced no result (matches known, still
  -open community confusion, aquasecurity/trivy discussions #6453 and
  #7087). Treat these `.rego` files as accurate-but-unverified until that's
  resolved; Checkov is the proven-working gate.

The `terraform_checkov` pre-commit hook needs an *absolute*
`--external-checks-dir` (`.pre-commit-config.yaml` passes
`__GIT_WORKING_DIR__/policies/checkov`), since
`antonbabenko/pre-commit-terraform`'s hook script `cd`s into each changed
directory before running `checkov -d .` — a relative path in `checkov.yaml`
alone would silently resolve to nothing there.
