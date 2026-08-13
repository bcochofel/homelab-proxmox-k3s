# CLAUDE.md

Project context for Claude Code sessions — **not for humans**: never link or
reference this file from `README.md`, `CONTRIBUTING.md`, `TODO.md`, or
anything under `docs/`. A human contributor's path is root `README.md`
(Quickstart, end-to-end) -> `docs/*.md` -> `CONTRIBUTING.md`, with `TODO.md`
as the standing phase-status tracker. The per-tool READMEs
(`packer/README.md`, `terraform/README.md`, `ansible/README.md`) are
deliberately just one-line pointers to their `docs/<TOOL>.md`.
`packer/ubuntu-26.04/README.md` is the exception that holds real content —
build steps and ADRs — since `packer/` is designed to hold multiple OS
templates over time and its own README stays generic.

## What this is

Three VMs on Proxmox — one K3s server, two K3s agents — built with the
Packer -> Terraform -> Ansible pipeline, running a K3s cluster managed
GitOps-style by ArgoCD:

```text
Packer (template) -> Terraform (clone VMs + generate inventory)
  -> Ansible (K3s + Traefik + ArgoCD bootstrap) -> ArgoCD (app-of-apps GitOps)
```

Topology:

- `k3s-srv1` (`192.168.68.25`) — K3s server (control-plane), single node, no
  HA embedded-etcd.
- `k3s-agent1`/`k3s-agent2` (`192.168.68.26`/`.27`) — K3s agents (workers).

This repo is the third leg of a three-repo homelab: `homelab-proxmox-core`
(Caddy reverse proxy + DNS), `homelab-proxmox-elastic` (Elasticsearch +
Kibana + Fleet Server + APM Server), and this one. The end goal spans all
three:
one shared Elastic Observability stack — metrics, logs, and APM — with
this repo's K3s cluster (running the OpenTelemetry demo) as a workload
that feeds it, not a second parallel observability stack. Secondary goal:
this repo is where the Kubernetes/ArgoCD half gets learned, same way the
elastic repo is where Elastic Observability gets learned.

## Decisions that are deliberate (do not "fix" these)

- **Terraform Provider is `bpg/proxmox`, same as core/elastic**, with a
  copy of their shared `terraform/modules/vm` module — **one local
  change**: `nameserver` is `list(string)` here (both `192.168.68.42`
  CoreDNS and `.43` Pihole), not a single string, for resolver redundancy.
  This repo predates the bpg/modules-vm architecture (it used to run
  Telmate + a bespoke `for_each` block) and was rewritten onto it for
  structural parity with the other two repos, not migrated incrementally.
- **Terraform State: HCP Terraform**, workspace `k3s-cluster` (carried
  forward from the pre-refactor version of this repo, not renamed).
- **Topology (1 server + 2 agents, 2 vCPU/4GB/50GB each) was sized against
  live Proxmox capacity, not picked round.** `pve1` has 16 vCPU/62.5GB
  total; the core+elastic repos' VMs already allocate ~13 vCPU/~35GB
  before this cluster exists. Adding 6 vCPU/12GB brings the host to
  19 vCPU/47GB allocated (1.19x CPU overcommit — comfortable given every
  existing VM idles at low single-digit CPU%). A 3-server HA control plane
  was considered and rejected for now (would push to 25 vCPU/47GB, a
  1.56x overcommit, for HA this homelab doesn't need) — see `TODO.md` if
  that tradeoff is ever revisited. Disk is 50GB (not 40GB) per node,
  matching the `ubuntu-26.04-k3s` Packer template's disk size — the bpg
  provider can't shrink a cloned disk below its source, so Terraform's
  `disk` var can't go lower than whatever `packer/ubuntu-26.04/
  variables.auto.pkrvars.hcl`'s `disk_size` was built with.
- **Packer builds `ubuntu-26.04-k3s`** (vmid `9003` — `9001` is elastic's
  template, `9002` is core's), adapted from the core repo's minimal
  Docker-only template. **Docker is baked in for parity/debugging
  convenience only** — K3s doesn't need it, it ships its own embedded
  containerd. Swap-disable, kernel modules (`overlay`/`br_netfilter`), and
  the related sysctls are handled by Ansible's `k3s_common` role after
  boot, not by Packer.
- **K3s and ArgoCD are installed via their own official install
  scripts/manifests (`get.k3s.io`, ArgoCD's `install.yaml`), pinned to an
  exact version in `ansible/inventory/group_vars/all.yml`** — not a
  Kubernetes-specific Ansible collection, not Helm for ArgoCD's own
  install. Both are shelled out to directly via `kubectl`/`curl | sh`,
  matching this project's general "use the tool already required, don't
  add a dependency for idempotent applies" preference (see
  `.pre-commit-config.yaml`'s local `packer_fmt`/`ansible_lint` hooks for
  the same pattern elsewhere).
- **Traefik terminates its own TLS via Cloudflare DNS-01 — it is not
  proxied through the core repo's Caddy.** K3s bundles Traefik as its
  default ingress controller (`k3s_server` never passes `--disable
  traefik`); the `traefik` role configures it with a `HelmChartConfig`
  (K3s' officially supported way to customize a bundled addon's Helm
  values) rather than installing a second one. Deliberate divergence from
  the homelab's usual "every fqdn routes through Caddy" convention
  (`homelab-proxmox-core`'s `CLAUDE.md`) — this repo exists partly to
  build hands-on Kubernetes/ingress-controller skills, so Traefik running
  its own real ACME setup is more useful to learn on than routing
  everything through Caddy would be. Own Cloudflare API token, same
  least-privilege-per-consumer boundary as every other token in this
  homelab (see "Credentials & secrets" below). Full rationale:
  `docs/ARGOCD.md`.
- **ArgoCD is bootstrapped app-of-apps style.** Ansible's `argocd` role
  applies exactly one manifest, `argocd/root-app.yaml`, which points
  ArgoCD's own sync back at this repo's `argocd/apps/` directory. Every
  app after that — starting with `argocd/apps/otel-demo.yaml` — is pure
  GitOps: a new file, committed and pushed, no Ansible re-run. See
  `docs/ARGOCD.md`.
- **The OpenTelemetry demo is routed to the elastic repo's apm-server VM
  (`192.168.68.34:8200`), not the chart's bundled Jaeger/Prometheus/
  OpenSearch/Grafana** (`jaeger.enabled`/`prometheus.enabled`/
  `opensearch.enabled`/`grafana.enabled` all `false` in
  `argocd/apps/otel-demo.yaml`). This is the whole point of the
  three-repo architecture (one shared observability stack, not one per
  repo) and also meaningfully shrinks the demo's footprint on this
  cluster's tight resource budget. The apm-server endpoint is plain HTTP,
  no auth — confirmed by reading the elastic repo's
  `ansible/roles/fleet_bootstrap/tasks/main.yml` directly (its APM
  integration package policy sets only `host`, no `secret_token`/TLS), not
  assumed from Elastic's docs in general. Full rationale and the "if that
  ever changes" contingency: `docs/ARGOCD.md`.
- **`nameserver` on this repo's VMs is a list, not a single string** — the
  one place this repo's `modules/vm` diverges from the core/elastic
  original. Both `.42` (CoreDNS) and `.43` (Pihole) are set, for
  redundancy; core/elastic currently only set one.
- **Only `hosts.ini` is generated.** `ansible/inventory/group_vars/` is
  hand-authored and must never be overwritten by Terraform — same
  standing rule as core/elastic.
- **Terraform and Ansible are decoupled** — no `local-exec` chaining. Run
  `terraform apply` (from `terraform/`) then
  `ansible-playbook playbooks/site.yml` (from `ansible/`) as two separate,
  explicit commands.
- **The Makefile only has non-mutating targets** (`packer-init`, `tf-init`,
  `ansible-deps`, plus tool install/check). `packer build`, `terraform
  apply`, and `ansible-playbook` are deliberately NOT Makefile targets — run
  them directly, by hand, from their own directory.

## Execution environment & tooling decisions

Linux only — Ubuntu, whether that's WSL2 or a native Linux workstation, never
PowerShell. Claude Code must be launched from the repo root so `packer`,
`terraform`, `ansible-playbook` (via `.venv/`), `kubectl`, and `sops`
resolve correctly.

Pipeline order is fixed: **Packer → Terraform → Ansible (K3s → Traefik →
ArgoCD) → GitOps**. Do not skip ahead — ArgoCD only exists once Ansible's
`argocd` role has run, which only makes sense once the K3s cluster (and
Traefik's cert resolver, if any Ingress needs TLS on first sync) is up,
which only makes sense once Terraform has cloned the VMs from the Packer
template.

## Credentials & secrets

- Secrets live in `secrets.yaml`, SOPS-encrypted with **age**. `.sops.yaml`
  and `secrets.yaml` are **user-managed for this repo, not generated by an
  agent session** — copied and hand-edited from the core or elastic repo's
  own `secrets.yaml` (dropping keys this repo doesn't need — e.g.
  `pihole_webpassword` — keeping/renaming whatever this repo's `.envrc`
  files actually reference: `proxmox_terraform_token_id/secret`,
  `proxmox_packer_token_id/secret`, `cloudinit_password`,
  `tf_cloud_token`, `cloudflare_api_token`). `cloudflare_api_token` is
  kept under the *same key name* the core repo uses, but its *value* must
  be this repo's own separately-scoped token, not a copy of core's — see
  "Traefik" in the decisions list above. Whatever age recipient ends up
  in `.sops.yaml` — shared with another repo's or freshly generated for
  this one — is a call the human made directly, not something to second-
  guess or "fix" back to the one-key-per-repo pattern core/elastic use.
- **direnv** loads credentials per-directory. Root `.envrc` decrypts once
  (`sops -d --output-type dotenv secrets.yaml`) and child dirs inherit via
  `source_up`. `packer/`, `terraform/`, `ansible/` each add tool-specific
  vars — `ansible/.envrc` exports `CLOUDFLARE_API_TOKEN` for the `traefik`
  role (see `docs/ANSIBLE.md`'s "Secrets" section); nothing else in the
  K3s/ArgoCD install path needs an external API token.
- direnv runs in the human's shell *before* the agent starts. The Claude
  Code deny rule on `sops -d` restricts the agent, not direnv — both hold.
- Never read, print, echo, `cat`, `head`, `grep`, or `sed` any `.envrc`,
  `secrets.yaml`, or the age key. Reference secrets by variable name only.
- **`secrets.yaml` is meant to be committed** (it's ciphertext). Never add
  `secrets.yaml`/`secrets.yml` to `.gitignore` — a bug in an earlier
  version of the core repo did exactly that (silently blocked the file
  from ever being committed); stays fixed everywhere it was copied from.
  Only decrypted output (`*.decrypted`, `*.dec.yaml`, `secrets.dec.yaml`)
  should ever be ignored.

## Proxmox auth — two tokens

- **packer@pve!packer-automation** — template build rights. Same Proxmox
  user the core/elastic repos already created (one Proxmox user, multiple
  tokens, one per repo) — see `docs/PACKER.md`.
- **terraform@pve!terraform-automation** — clone/configure rights + SSH to
  the PVE node for bpg file uploads. See `docs/TERRAFORM.md`'s privilege
  table for the exact `pveum` commands.
- Env var shapes: Packer `PKR_VAR_*`; Terraform `PROXMOX_VE_*` /
  `TF_VAR_proxmox_api_token` (bpg/proxmox reads these directly).

## Terraform Cloud

Remote **state only**. Workspace Execution Mode = **Local**, because Proxmox
is LAN-only and HCP's infra can't reach it. `cloud {}` block
(`terraform/versions.tf`) points at org `homelab-bcochofel-com`, workspace
`k3s-cluster`. Always `plan` and show output; never `apply` unprompted;
never `destroy`.

## Command permissions (.claude/settings.json)

Same philosophy as core/elastic: local, read-only/validating checks run
freely (now including read-only `kubectl`/`k3s kubectl`/`helm`/`argocd`
commands — `get`, `describe`, `version`, `rollout status`, `app list`);
anything that actually writes infrastructure or cluster state requires a
human click every time. See `.claude/settings.json` for the exact
allow/ask/deny lists. Use the `update-config` skill for future changes
here.

## Standing rules

- **Never overwrite `inventory/group_vars/`.** Terraform generates
  `hosts.ini`; `inventory/group_vars/` is hand-authored.
- Run `terraform validate` on every change — the provider schema will be
  hallucinated confidently otherwise.
- K3s/ArgoCD/the OpenTelemetry demo chart all move fast and post-date the
  training cutoff: verify current stable versions live (`gh api
  repos/<org>/<repo>/releases/latest`, not memory) before bumping any pin
  in `ansible/inventory/group_vars/all.yml` or `argocd/apps/*.yaml`.

## Commands

```bash
make install   # pinned CLI binaries, direnv approval, pre-commit hooks,
               # Ansible virtualenv + collections — everything a
               # contributor needs, one shot
```

Individual pieces, if you need to re-run just one — see `make help` for the
full list (`check`, `direnv-allow`, `pre-commit-install`, `venv`,
`ansible-install`, `ansible-deps`, `packer-init`, `tf-init`).

The write ops have no Makefile target — run them directly:

```bash
cd packer/ubuntu-26.04 && packer build .
cd terraform && terraform apply -parallelism=1
cd ansible && ../.venv/bin/ansible-playbook playbooks/site.yml
```

(`-parallelism=1` is optional, not required — Proxmox locks the template
while cloning, so cloning the three VMs in parallel just serializes anyway;
the flag only trims the extra lock-wait noise from the output. Confirmed
in practice: a plain `terraform apply` with no flag completed successfully.)

## Before first run

1. `make install`.
2. Set in tfvars / HCP / env: `target_node` (`pve1`), `vm_template`
   (`ubuntu-26.04-k3s`), `TF_VAR_proxmox_api_token`, `TF_VAR_cipassword`.
3. Fill in `secrets.yaml` for real (`sops secrets.yaml`) — see "Credentials
   & secrets" above for which keys, **including `cloudflare_api_token`**
   (Traefik's DNS-01 token) — the `traefik` role's preflight fails loudly
   if it's empty.
4. After `ansible-playbook playbooks/site.yml` succeeds: add a DNS record
   for `otel-demo.homelab.bcochofel.com` (pointed at `k3s-srv1`,
   `192.168.68.25`) to the **core repo's** `dns_hosts` — manual,
   cross-repo, not something this repo's Ansible can do. See
   `docs/ARGOCD.md`.

## Open / deferred work

Tracked in [`TODO.md`](TODO.md), not duplicated here.
