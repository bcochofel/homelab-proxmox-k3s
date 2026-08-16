# homelab-proxmox-k3s

Three VMs on Proxmox (pve1), built with an IaC pipeline into a K3s cluster,
running the OpenTelemetry demo managed by ArgoCD.

```text
Packer (template) -> Terraform (clone VMs + generate inventory)
  -> Ansible (K3s + ArgoCD bootstrap) -> ArgoCD (GitOps)
```

## Homelab architecture

This repo is one of three that make up the homelab:

- **`homelab-proxmox-k3s`** (this repo) — a K3s cluster managed via ArgoCD
  (GitOps), with Traefik as its in-cluster ingress, running the
  OpenTelemetry demo. It sends its traces/metrics/logs to the
  `homelab-proxmox-elastic` stack's APM Server rather than a bundled
  Jaeger/Prometheus/OpenSearch/Grafana stack of its own — so this cluster
  is part of the shared observability architecture, not a second, separate
  one. See [`docs/ARGOCD.md`](docs/ARGOCD.md) for the full rationale.
- **[`homelab-proxmox-core`](https://github.com/bcochofel/homelab-proxmox-core)**
  — edge routing and name resolution: the Caddy reverse proxy and the
  CoreDNS + Pihole DNS pair every VM in the homelab (including this
  repo's) resolves against.
- **[`homelab-proxmox-elastic`](https://github.com/bcochofel/homelab-proxmox-elastic)**
  — the Elastic observability stack (Elasticsearch, Kibana, Fleet Server,
  APM Server), built with the same Packer -> Terraform -> Ansible pipeline
  as this repo.

## Quickstart

Get the cluster green on Proxmox, end to end. See
[Design decisions](#design-decisions) below for topology and rationale, and
[`CONTRIBUTING.md`](CONTRIBUTING.md) if you're setting this up to
contribute rather than just to run it.

### Prerequisites

- A Proxmox VE node reachable on your LAN (`pve1`), with an Ubuntu Server
  ISO (26.04) already uploaded to its ISO storage.
- Two Proxmox API tokens, each scoped to least privilege for what it does:
  one for Packer (template builds), one for Terraform (clone/configure the
  VMs) — the same Proxmox users the core/elastic repos already created,
  just minted with their own token secret for this repo. See
  [`docs/PACKER.md`](docs/PACKER.md) for the exact `pveum` commands;
  Terraform's token setup is in [`docs/TERRAFORM.md`](docs/TERRAFORM.md).
- `age` and `sops` installed, plus a `secrets.yaml` at the repo root
  holding the Proxmox tokens and cloud-init password the `.envrc` files
  decrypt per directory — see "Secrets management" below.
- `direnv` installed and hooked into your shell.
- `pre-commit` installed if you plan to commit changes (see
  [`CONTRIBUTING.md`](CONTRIBUTING.md)).
- `kubectl`, `helm`, `k9s`, `kubectx`/`kubens` — all installed and
  version-pinned by `make install` (see Commands below). None of these are
  needed by the pipeline itself (Ansible/ArgoCD do their own thing); they're
  for inspecting the cluster directly once it's up.
- A Cloudflare API token scoped to the `bcochofel.com` zone — **Zone → DNS
  → Edit** + **Zone → Zone → Read** permissions — for Traefik's Let's
  Encrypt DNS-01 challenge. Create a dedicated token for this repo; don't
  reuse the one the core repo's Caddy uses, even though it's the same
  zone.

### Secrets management (SOPS + age)

Every credential this repo needs — Proxmox API tokens, the cloud-init
password hash, Traefik's Cloudflare token — lives in one file,
`secrets.yaml` at the repo root,
encrypted at rest with [SOPS](https://github.com/getsops/sops) using an
[age](https://github.com/FiloSottile/age) key. Unlike most `secrets.*`
naming conventions, **this file is meant to be committed** — SOPS encrypts
the values in place, so the file in git is ciphertext, safe to version
alongside the code that needs it. What must never be committed is the age
*private* key or a decrypted copy of the file — both are covered by
`.gitignore`.

**Setup for this repo:** copy `secrets.yaml` from the core or elastic repo
and hand-edit it — drop keys this repo doesn't need (e.g.
`pihole_webpassword`), keep `cloudflare_api_token` **but replace its value**
with this repo's own dedicated token (see "Prerequisites" above — same key
name as the core repo's, different value, since each repo's `secrets.yaml`
is independent), keep/rename the rest of the keys this repo's `.envrc`
files actually reference (see the table below). Whether you
reuse that repo's age key (same `.sops.yaml` recipient) or generate a fresh
one for this repo specifically is your call:

```bash
# Only if you want a repo-specific age key instead of reusing an existing one:
age-keygen -o ~/.config/sops/age/keys.txt   # appends if the file already exists
chmod 600 ~/.config/sops/age/keys.txt
```

Paste whichever public key (`age1...`) you're using into
[`.sops.yaml`](.sops.yaml) as the recipient before creating/re-encrypting
`secrets.yaml`.

**Creating or editing `secrets.yaml`:**

```bash
sops secrets.yaml
```

This decrypts into a temp file, opens your `$EDITOR`, and re-encrypts on
save. Keys this repo's `.envrc` files expect:

| Key | Used by |
| --- | --- |
| `proxmox_packer_token_id` / `proxmox_packer_token_secret` | Packer |
| `proxmox_terraform_token_id` / `proxmox_terraform_token_secret` | Terraform |
| `tf_cloud_token` | Terraform (HCP Terraform) |
| `cloudinit_password` | Packer + Terraform (cloud-init user password) |
| `cloudflare_api_token` | Ansible (Traefik's DNS-01 ACME) — a repo-specific token value, not shared with the core repo's |

See [`docs/ANSIBLE.md`](docs/ANSIBLE.md)'s "Secrets" section for more on
that last one.

**Viewing decrypted content (read-only):**

```bash
sops -d secrets.yaml
```

**How `direnv` uses it:** each directory's `.envrc` runs
`sops -d --output-type dotenv secrets.yaml` and exports the result as
environment variables (`PKR_VAR_*` for Packer, `TF_VAR_*` for Terraform).
Once `secrets.yaml` exists and your age key can decrypt it, `direnv allow`
(via `make install`) is all that's needed for those variables to appear
automatically when you `cd` into `packer/`, `terraform/`, etc.

**After editing `secrets.yaml` itself:** no action needed — direnv re-runs
`.envrc` automatically the next time you `cd` into a directory, or
immediately via `direnv reload`.

**After editing any `.envrc` file:** direnv treats a changed `.envrc` as
untrusted and blocks it until re-approved:

```bash
make direnv-allow
```

### 0. Prepare the local environment

```bash
make install
```

Pins the CLI binaries this repo needs (`terraform`, `packer`, `trivy`,
`tflint`, `terraform-docs`, `sops`) into `~/bin`, approves the `.envrc`
files (root, `packer/`, `terraform/`, `ansible/`) via direnv, and creates
the `.venv/` Ansible runs from.

### 1. Build the VM template (Packer)

```bash
make packer-init
cd packer/ubuntu-26.04
cp variables.pkrvars.hcl.example variables.auto.pkrvars.hcl   # fill in, gitignored, auto-loaded
packer build .
```

See [`packer/ubuntu-26.04/README.md`](packer/ubuntu-26.04/README.md) for
what it bakes in and why.

### 2. Clone the VMs and generate the inventory (Terraform)

```bash
cd terraform
cp example.tfvars terraform.tfvars   # edit, or set the equivalent HCP workspace variables
terraform init    # one time
terraform plan    # review before applying
terraform apply
```

Add `-parallelism=1` if you want quieter output: Proxmox locks the
template while cloning, so cloning all three VMs in parallel just
serializes anyway — the flag is optional, it only trims the extra
lock-wait noise, not required for a successful apply. This clones the
Packer template into `k3s-srv1`/`k3s-agent1`/
`k3s-agent2`, assigns each a static IP, and writes
`ansible/inventory/hosts.ini` — see [`docs/TERRAFORM.md`](docs/TERRAFORM.md),
including the `pveum` commands to create the `terraform@pve` token if you
haven't already.

### 3. Bootstrap K3s + ArgoCD (Ansible)

```bash
source .venv/bin/activate   # from repo root
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/site.yml
```

Runs bootstrap -> K3s server -> Cilium CNI (kube-proxy replacement,
Hubble) -> K3s agents -> Traefik (Cloudflare DNS-01 cert resolver) ->
ArgoCD install + app-of-apps -> health check. See
[`docs/ANSIBLE.md`](docs/ANSIBLE.md) for the role/playbook breakdown.

**Before this succeeds:** `CLOUDFLARE_API_TOKEN` must be set in
`secrets.yaml` and exported from `ansible/.envrc` — the `traefik` role's
preflight check fails loudly and early if it's missing.

Once done, add DNS records for `otel-demo.homelab.bcochofel.com`,
`argocd.homelab.bcochofel.com`, and `hubble.homelab.bcochofel.com`,
all pointed at `k3s-srv1` (`192.168.68.40`), in the **core repo's**
`ansible/inventory/group_vars/dns.yml` — manual, cross-repo, see
[`docs/ARGOCD.md`](docs/ARGOCD.md) — then see [Verify](#verify) below.

### 4. Everything past this point is GitOps

`ansible-playbook playbooks/site.yml` applies exactly one ArgoCD
`Application` directly (`argocd/root-app.yaml`) — everything else,
starting with the OpenTelemetry demo (`argocd/apps/otel-demo.yaml`), syncs
on its own once ArgoCD is up. Adding a new app is a new file under
`argocd/apps/`, committed and pushed — see
[`docs/ARGOCD.md`](docs/ARGOCD.md).

## Topology

| VM | vCPU | RAM | Disk | Role | IP |
| --- | --- | --- | --- | --- | --- |
| k3s-srv1 | 4 | 8 GB | 50 GB | K3s server (control-plane) | 192.168.68.40 |
| k3s-agent1 | 2 | 4 GB | 50 GB | K3s agent (worker) | 192.168.68.41 |
| k3s-agent2 | 2 | 4 GB | 50 GB | K3s agent (worker) | 192.168.68.42 |

Single-server topology, no HA embedded-etcd — originally sized 2 vCPU/4GB
per node against `pve1`'s live capacity at refactor time (16 vCPU/62.5 GB
total, ~13 vCPU/~35 GB already allocated to the core/elastic repos' VMs);
`k3s-srv1` was later bumped to 4 vCPU/8GB after a live resource-exhaustion
incident. See `CLAUDE.md` for the full math, the incident, and what
growing to a 3-server HA control plane would change.

## Verify

- `kubectl get nodes` — all three should be `Ready`.
- `kubectl -n argocd get applications` — `root` and `otel-demo` both
  `Synced`/`Healthy` (the latter can take a few minutes on first sync —
  see `docs/ANSIBLE.md`'s healthcheck notes).
- `kubectl -n otel-demo get pods` — everything `Running`, nothing stuck
  `Pending`.
- `https://argocd.homelab.bcochofel.com` — ArgoCD's own WebUI, fronted by
  Traefik (default admin password in the `argocd-initial-admin-secret`
  Secret in the `argocd` namespace until it's rotated). `kubectl -n argocd
  port-forward svc/argocd-server 8080:443` still works as a fallback if
  the Ingress/DNS isn't reachable. See [`docs/ARGOCD.md`](docs/ARGOCD.md).
- `https://otel-demo.homelab.bcochofel.com` — the demo's storefront UI.
- `https://hubble.homelab.bcochofel.com` — Hubble UI (Cilium's flow/
  service-map visualizer). No authentication of its own — see
  `CLAUDE.md`'s Cilium decision entry for why that's an accepted tradeoff
  here.

All three are served with a real Let's Encrypt cert issued by Traefik
itself (once the DNS records above are in place and the cert resolver has
had a moment to issue them) — confirms Traefik's own ingress and DNS-01
cert resolver are working. Traefik's own dashboard isn't exposed
(`--api.dashboard`/`--api.insecure` aren't set in the `traefik` role's
`HelmChartConfig`).

## Design decisions

- **Provider:** `bpg/proxmox`, same shared `modules/vm` module as
  core/elastic (with one local change: `nameserver` is a list here, both
  CoreDNS and Pihole).
- **State:** HCP Terraform, workspace `k3s-cluster`.
- **K3s + ArgoCD install:** official install script/manifest, pinned
  version, plain `kubectl`/`curl | sh` — no extra Ansible collection.
- **GitOps:** app-of-apps — Ansible applies one root `Application`,
  everything else is a file under `argocd/apps/`.
- **Ingress/TLS:** K3s' bundled Traefik, configured with its own
  Cloudflare DNS-01 cert resolver (own token, independent of core's
  Caddy) — terminates TLS itself rather than proxying through Caddy.
- **Observability:** the OpenTelemetry demo's bundled Jaeger/Prometheus/
  OpenSearch/Grafana are disabled; its collector exports to the elastic
  repo's apm-server instead. One shared Elastic Observability stack across
  all three repos, not a second one per repo.
- **Inventory:** only `ansible/inventory/hosts.ini` is generated.
  `ansible/inventory/group_vars/` is hand-authored and never overwritten.
- **Decoupling:** Terraform and Ansible are run as separate, explicit
  commands — no `local-exec` chaining, no Makefile wrapper around either
  write step.
- **Template:** `ubuntu-26.04-k3s`, minimal (Docker included for parity/
  debugging, not required by K3s itself).

## Documentation

- [`docs/PACKER.md`](docs/PACKER.md) — VM template build.
- [`docs/TERRAFORM.md`](docs/TERRAFORM.md) — cloning the VMs + inventory generation.
- [`docs/ANSIBLE.md`](docs/ANSIBLE.md) — K3s + ArgoCD bootstrap.
- [`docs/ARGOCD.md`](docs/ARGOCD.md) — the GitOps layer + OpenTelemetry demo.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — environment setup, branching, commit
  conventions, and versioning for contributors.
- [`TODO.md`](TODO.md) — phase-by-phase roadmap and current status.

## References

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Proxmox Cloud-Init Support](https://pve.proxmox.com/wiki/Cloud-Init_Support)
- [K3s Documentation](https://docs.k3s.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [OpenTelemetry Demo](https://opentelemetry.io/docs/demo/)
