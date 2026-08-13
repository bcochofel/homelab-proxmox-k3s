# TODO / Roadmap

The single place phase status lives. When a phase is done, check it off
here — no need to also edit `README.md` or `CLAUDE.md`; both point here
instead of duplicating status inline.

## Phase 0 — Refactor to the core/elastic-repo architecture

- [x] Rebuild the repo structure to mirror `homelab-proxmox-core`/
      `homelab-proxmox-elastic`: `bpg/proxmox` + shared `modules/vm`,
      Packer template, HCP Terraform (`k3s-cluster` workspace),
      SOPS+direnv secrets convention, custom Checkov/Trivy Proxmox
      policies, semantic-release, CLAUDE.md/TODO.md/docs split.
- [x] Design and write the K3s (server/agent) + ArgoCD (app-of-apps)
      Ansible roles and the `argocd/` GitOps manifests, including routing
      the OpenTelemetry demo to the elastic repo's apm-server instead of
      its own bundled Jaeger/Prometheus/OpenSearch/Grafana.
- [x] Design and write the `traefik` role (Cloudflare DNS-01 cert resolver
      via `HelmChartConfig` on K3s' bundled Traefik) and wire the
      otel-demo Application's `frontend-proxy` Ingress + the
      `PUBLIC_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` env override it needs.
- [x] Fill in `secrets.yaml` for real (`sops secrets.yaml`) — Proxmox
      tokens (Packer + Terraform), cloud-init password, HCP Terraform
      Cloud token, Traefik's Cloudflare API token. User-owned step, not
      done as part of the refactor — see `CLAUDE.md`'s "Credentials &
      secrets".
- [x] Generate/confirm the age recipient in `.sops.yaml` for this repo
      (shared with another repo's key or fresh — human's call).

## Phase 1 — Green K3s cluster

- [x] Packer: `ubuntu-26.04-k3s` template builds cleanly (Docker, initrd
      network fix).
- [x] Terraform: `k3s-srv1`/`k3s-agent1`/`k3s-agent2` VMs clone from the template,
      static IPs `192.168.68.25`-`.27`, inventory generated.
- [x] Ansible: `common` preflight passes, `k3s_common` prereqs apply
      cleanly, `k3s_server` brings up the control plane, `k3s_agent` joins
      both agents. `kubectl get nodes` shows all three `Ready`.
- [x] Fetch a working kubeconfig to the workstation running Ansible and
      merge it into `~/.kube/config` (`playbooks/99-healthcheck.yml`'s
      final tasks — fetch, rewrite `127.0.0.1` to the real server IP,
      rename off K3s' generic `default` naming, flatten-merge so other
      cluster contexts survive) — `kubectl`/`helm`/`k9s`/`kubectx` all
      work against the live cluster with zero flags/env vars, confirmed,
      including that a pre-existing unrelated context in `~/.kube/config`
      survives the merge untouched.

## Phase 2 — Green ArgoCD + Traefik

- [x] `traefik` role applies cleanly — `kube-system` Secret created,
      `HelmChartConfig` applied, `kubectl -n kube-system rollout status
      deploy/traefik` succeeds, confirmed live. The
      `additionalArguments`/`env`/`persistence` values keys do match the
      Traefik chart K3s v1.36.3+k3s1 vendors.
- [x] `argocd` role installs cleanly, `argocd-server` deployment reaches
      `Available`, confirmed live.
- [ ] `argocd/root-app.yaml` syncs successfully — `kubectl -n argocd get
      applications` shows `root` as `Synced`/`Healthy`. Currently stuck at
      `Unknown`/`Healthy`: repo-server clones `homelab-proxmox-k3s.git`
      fine but `argocd/apps` doesn't exist on `origin/main` yet — the
      whole bpg/K3s/ArgoCD rewrite has been sitting uncommitted locally
      this entire time. Blocks on merging the rewrite PR (2.0.0) to
      `main`; re-check once that lands.
- [ ] ArgoCD UI reachable (`kubectl -n argocd port-forward svc/argocd-server
      8080:443`) with the initial admin password from
      `argocd-initial-admin-secret` — mechanism documented (`docs/
      ARGOCD.md`, README's Verify section), not yet exercised in a
      browser. Rotate the password once confirmed working.

## Phase 3 — This cluster as a workload in the Elastic Observability stack

Per `CLAUDE.md`: this cluster's entire reason for existing is to be a
workload feeding the **same shared** Elastic Observability stack the
core/elastic repos already run (`homelab-proxmox-elastic`'s Elasticsearch +
Kibana + Fleet Server + APM Server) — not a second, parallel observability
stack of its own. `otel-demo.yaml` already disables the chart's bundled
Jaeger/Prometheus/OpenSearch/Grafana and points its exporter at
`homelab-proxmox-elastic`'s APM Server (`192.168.68.34:8200`, plain HTTP,
no auth) instead — that's the design; everything below is what's still
needed to prove it actually works end to end, plus close the one real gap
(only demo-service traces flow today, not general node/pod logs):

- [ ] `otel-demo` Application syncs — `kubectl -n otel-demo get pods` all
      `Running`, nothing stuck `Pending` on insufficient CPU/memory
      (this cluster's 2-agent/4GB-each budget is sized against Proxmox
      capacity, not validated against the actual chart's footprint — see
      `CLAUDE.md`).
- [ ] Confirm traces/metrics/logs actually land in Kibana's APM/
      Observability UI, not just that the collector's exporter didn't
      error — `otel-demo.yaml`'s apm-server endpoint (plain HTTP, no auth)
      was confirmed from the elastic repo's Ansible task, not from a live
      end-to-end test yet.
- [ ] If pods are `Pending` on resource pressure: trim `otel-demo`'s
      `valuesObject` further (replica counts, resource requests) before
      reconsidering the node topology itself.
- [ ] Add the DNS record for `otel-demo.homelab.bcochofel.com` (pointed at
      `k3s-srv1`, `192.168.68.25`) to the **core repo's** `dns_hosts` —
      manual, cross-repo step, blocks reaching the demo by hostname at
      all. Confirm Traefik actually issues a real cert (`kubectl -n
      otel-demo describe ingress` / check for ACME errors in the
      `traefik` pod's logs) once that record resolves.
- [ ] Confirm browser-side traces actually arrive (open the demo UI, place
      an order, check the trace shows up in Kibana) — validates the
      `PUBLIC_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` override in
      `otel-demo.yaml` actually matches reality, not just that it's set.
- [ ] Decide whether the apm-server endpoint needs auth/TLS added on the
      elastic repo's side, and if so, add the matching `Authorization`
      header (+ certificate trust) to `otel-demo.yaml`'s
      `otlphttp/elastic` exporter — see `docs/ARGOCD.md`.
- [ ] Ship general K3s node/pod log collection to Elastic (a
      `filelog`/log-collection preset, or a Fleet-managed Elastic Agent
      DaemonSet matching the core/elastic repos' pattern more directly) —
      today only the demo services' own OTel SDK logs flow through;
      arbitrary pod logs and node-level logs don't. This is the biggest
      remaining gap between "otel-demo reports to Elastic" and "this
      cluster is actually part of the observability stack" the way
      core/elastic's VMs already are (Fleet-managed Elastic Agent on
      every host).

## Phase 4 — Hardening / follow-up

- [ ] Install the Kubernetes MCP and ArgoCD MCP servers (requested
      alongside this refactor, deliberately deferred — MCP config is a
      `claude mcp add` change, not a repo file).
- [ ] Expose the ArgoCD UI via Traefik too (its own Ingress + hostname,
      e.g. `argocd.homelab.bcochofel.com`), instead of only
      `kubectl port-forward` — scoped out of the initial Traefik setup
      (which only covers otel-demo) to keep that change reviewable; same
      cert-resolver pattern applies directly. ArgoCD's own install
      manifest also needs `--insecure` or a TLS passthrough tweak on the
      `argocd-server` since it terminates its own TLS by default — check
      current ArgoCD docs for the supported way to front it with an
      external Ingress before implementing.
- [ ] Revisit K3s/ArgoCD/`opentelemetry-demo` chart version pins
      periodically (`ansible/inventory/group_vars/all.yml`,
      `argocd/apps/otel-demo.yaml`) — check
      `gh api repos/<org>/<repo>/releases/latest` for current stable
      before bumping, same discipline as the Caddy/CoreDNS/Pihole pins in
      the core/elastic repos.
- [ ] Revisit whether a 3-server HA control plane is worth the extra
      Proxmox headroom it costs — see `CLAUDE.md`'s topology-sizing note
      for the math as it stood at refactor time.
- [ ] `CKV_PROXMOX_1` (UEFI firmware) is a real, unaddressed gap in
      `modules/vm/main.tf`, carried over from core/elastic and currently
      skip-listed in `checkov.yaml` — same fix needed in all three repos
      if it's ever addressed (`bios = "ovmf"` + an `efi_disk` block).

See `CLAUDE.md` for the detailed technical notes and decisions behind each
of these (agent-facing context) — this file is just the status list.
