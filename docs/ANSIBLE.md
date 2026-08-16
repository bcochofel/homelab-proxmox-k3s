# Ansible — K3s + ArgoCD bootstrap

Third stage of the pipeline: configures the VMs Terraform just cloned,
turns them into a K3s cluster, and bootstraps ArgoCD's app-of-apps on top.
Run from `ansible/`, using the repo-root `.venv/` (`make ansible-install`
pins `ansible`/`ansible-lint`; `ansible-galaxy collection install -r
requirements.yml` pulls `ansible.utils`/`community.general`).

```bash
cd ansible
../.venv/bin/ansible-galaxy collection install -r requirements.yml
../.venv/bin/ansible-playbook playbooks/site.yml
```

## Roles

- **`common`** — preflight checks only (`roles/common/tasks/asserts.yml`):
  confirms the host is Ubuntu >= 22.04 and Docker is present (baked in by
  Packer for parity with the sibling repos — this role never installs it;
  K3s itself doesn't need Docker, it ships its own embedded containerd).
  No secret preflight in `common` itself — unlike the core/elastic repos,
  neither K3s nor ArgoCD's own install depends on an external API token.
  (Traefik's cert resolver does need one, but that preflight lives in the
  `traefik` role below, checked right before it's needed rather than up
  front for every host.)
- **`k3s_common`** — host prerequisites shared by every node, server and
  agent alike, run before K3s itself installs: disables swap (`swapoff -a`,
  then comments out the `swap` line in `/etc/fstab` so it stays off across
  reboots), loads and persists the `overlay`/`br_netfilter` kernel modules,
  and sets the `net.bridge.bridge-nf-call-iptables`/`net.ipv4.ip_forward`
  sysctls K3s' embedded containerd/networking needs. Idempotent throughout.
- **`k3s_server`** — installs K3s in server (control-plane) mode via the
  official `get.k3s.io` script, pinned to `k3s_version`
  (`inventory/group_vars/all.yml`), idempotent via `creates=
  /usr/local/bin/k3s`. Reads back `/var/lib/rancher/k3s/server/node-token`
  into a fact (`k3s_node_token`) so `k3s_agent` can join without a
  separate lookup step. Single-server topology today — see `CLAUDE.md` for
  what a 3-server HA control plane would change here (`--cluster-init` +
  `--server` joins, not built ahead of need).
- **`k3s_agent`** — joins a host to the cluster in agent (worker) mode,
  same install script with `INSTALL_K3S_EXEC=agent`, `K3S_URL`/`K3S_TOKEN`
  read from the first `k3s_server` host's hostvars
  (`hostvars[groups['k3s_server'][0]]`). Requires the `k3s_server` play to
  have already run earlier in the same `ansible-playbook` invocation.
- **`cilium`** — runs once, `hosts: k3s_server[0]`, right after
  `k3s_server` and before agents join: `k3s_server`'s `INSTALL_K3S_EXEC`
  disables Flannel/kube-proxy (`--flannel-backend=none
  --disable-network-policy --disable-kube-proxy`), and this role installs
  Cilium as the replacement CNI via Cilium's own official `cilium` CLI
  (not K3s' `HelmChartConfig` mechanism — that installs charts via an
  in-cluster Job pod, which itself needs a working CNI to schedule, a
  chicken-and-egg problem once Flannel is gone). `cilium install` sets
  `kubeProxyReplacement=true`, points `k8sServiceHost`/`k8sServicePort` at
  the API server directly (kube-proxy normally provides that routing),
  and enables Hubble (relay + UI). Also applies a Traefik Ingress for
  Hubble UI (`hubble.homelab.bcochofel.com`). The "wait for the node to
  report Ready" check lives here, not in `k3s_server` — the node can't go
  Ready until a CNI exists. See `CLAUDE.md`'s "Decisions that are
  deliberate" for the full rationale.
- **`traefik`** — runs once, `hosts: k3s_server[0]`, after the cluster is
  up: configures K3s' *bundled* Traefik (already running as a default
  addon — `k3s_server` installs with no `--disable traefik`) with a
  Cloudflare DNS-01 cert resolver via a `HelmChartConfig` (the officially
  supported way to customize a K3s addon's Helm values — merges into the
  `traefik` HelmChart K3s itself manages, rather than installing a second,
  competing Traefik). Applies a `kube-system` Secret holding
  `CLOUDFLARE_API_TOKEN`, then the `HelmChartConfig`, then waits (with
  retries — K3s' own helm-controller needs a moment to notice the change
  and re-run `helm upgrade`) for the `traefik` deployment to roll out.
  Independent of the core repo's Caddy — its own ACME setup, own
  Cloudflare token. See [`docs/ARGOCD.md`](ARGOCD.md) for why.
- **`argocd`** — runs once, `hosts: k3s_server[0]`: applies ArgoCD's
  official install manifest (pinned `argocd_version`) into the `argocd`
  namespace, waits for `argocd-server`'s rollout, then applies this repo's
  `argocd/root-app.yaml` — the one app-of-apps `Application` Ansible
  manages directly. Plain `kubectl` throughout (K3s' install script
  symlinks a working one to `/usr/local/bin/kubectl`), not a Kubernetes
  Ansible collection — every apply here is already idempotent, so a new
  collection dependency wouldn't buy anything. See
  [`docs/ARGOCD.md`](ARGOCD.md) for what happens after this role hands off
  to ArgoCD.

## Inventory

- `inventory/hosts.ini` — **generated by Terraform**, gitignored.
  `[k3s_server]` and `[k3s_agent]` groups, each with its VM's
  Terraform-assigned IP, plus a `[k3s:children]` group covering both.
- `inventory/group_vars/all.yml` — **hand-authored, never overwritten**.
  Holds `k3s_install_url`/`k3s_version`, `argocd_version`/
  `argocd_namespace`, the app-of-apps root Application's
  repo/revision/path (`argocd_root_app_*` — informational; the actual
  values live in `argocd/root-app.yaml` itself, these just document them
  alongside the version pins), and Traefik's `traefik_acme_email`
  (not a secret, same pattern as core's `letsencrypt_email`) /
  `traefik_cloudflare_secret_name` / `traefik_cloudflare_api_token`
  (the last one a `lookup('env', 'CLOUDFLARE_API_TOKEN')`, not a literal
  value — see "Secrets" below).

## Playbooks

- `00-bootstrap.yml` — `hosts: k3s` (the `[k3s:children]` group), runs
  `common`.
- `10-k3s-server.yml` — `hosts: k3s_server`, runs `k3s_common` ->
  `k3s_server`.
- `15-cilium.yml` — `hosts: k3s_server[0]`, runs `cilium`. Between the
  server and agent plays — agents joining with no CNI yet is harmless
  (they just sit `NotReady` until Cilium's DaemonSet reaches them), but
  installing Cilium first keeps that window from opening at all.
- `20-k3s-agent.yml` — `hosts: k3s_agent`, runs `k3s_common` ->
  `k3s_agent`. Depends on `10-k3s-server.yml` having already run in the
  same invocation (needs `k3s_node_token` in hostvars).
- `25-traefik.yml` — `hosts: k3s_server[0]`, runs `traefik`.
- `30-argocd.yml` — `hosts: k3s_server[0]`, runs `argocd`.
- `99-healthcheck.yml` — `hosts: k3s_server[0]`: waits for every node to
  report `Ready` (`kubectl get nodes`), confirms `argocd-server`'s
  deployment is `Available`, then polls the root app-of-apps Application's
  sync/health status. The last check is deliberately non-fatal
  (`failed_when: false`) — pulling `opentelemetry-demo`'s chart from a
  public Helm repo and scheduling ~20 pods can legitimately take longer
  than a homelab node clears in the retry budget; it reports status rather
  than failing the whole run over slow-but-progressing sync. Finishes by
  `fetch`-ing `/etc/rancher/k3s/k3s.yaml` off the server to
  `ansible/k3s-homelab.kubeconfig` on the machine running Ansible (gitignored
  — it embeds a client cert/key), rewriting its `127.0.0.1` server address
  to the real IP, and renaming K3s' generic `default` cluster/context/user
  to `k3s-homelab`. That renamed copy is then merged into `~/.kube/config`
  (kubectl's default location) via `kubectl config view --flatten` — a
  true merge, not an overwrite, so any other cluster contexts already in
  that file survive untouched (verified: seeded a fake unrelated context
  before a run, confirmed it was still there after) — and set as the
  current context. `kubectl`/`helm`/`k9s`/`kubectx` all work immediately
  afterward with no flags or `KUBECONFIG` env var needed.
- `site.yml` — chains all seven via `import_playbook`, in order (bootstrap
  -> k3s server -> Cilium CNI -> k3s agents -> traefik -> argocd ->
  healthcheck). This is what `ansible-playbook playbooks/site.yml`
  actually runs.

## Secrets

`CLOUDFLARE_API_TOKEN` (the `traefik` role's Cloudflare DNS-01 token) comes
from `secrets.yaml` (SOPS + age) via `ansible/.envrc`'s `source_up` +
direnv chain — same mechanism as every other tool in this pipeline. A
preflight assert in the `traefik` role fails loudly and early if it
resolves empty, same pattern as core/elastic's Cloudflare/Pihole preflight
checks. This token should be its own, separately-scoped Cloudflare API
token (Zone:DNS:Edit + Zone:Zone:Read on `bcochofel.com`) — **not** the
same token value the core repo's Caddy uses, even though it's the same
Cloudflare zone and (confusingly) the same env var / secrets.yaml key
*name* (`cloudflare_api_token`/`CLOUDFLARE_API_TOKEN`) — each repo's
`secrets.yaml` is its own independent file, so reusing the name causes no
collision, but the *value* should still be a distinct token so a
leaked/rotated credential in one repo doesn't affect the other.

Nothing else needs a secret today — K3s' install script and ArgoCD's
install manifest are both self-contained.
