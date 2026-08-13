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
- [x] `argocd/root-app.yaml` syncs successfully — `kubectl -n argocd get
      applications` shows `root` as `Synced`/`Healthy`, confirmed live
      after the 2.0.0 rewrite PR (#13) merged to `main`. Needed one manual
      hard-refresh (`kubectl -n argocd annotate application root
      argocd.argoproj.io/refresh=hard --overwrite`) to bypass ArgoCD's
      cached pre-merge `ComparisonError` rather than waiting out its
      ~3min git polling interval — not a bug, just cache staleness.
- [x] ArgoCD UI reachable at `https://argocd.homelab.bcochofel.com` via
      Traefik (real Let's Encrypt cert via the `cloudflare` DNS-01
      resolver, same as otel-demo), not just `kubectl port-forward` —
      `ansible/roles/argocd`'s new `argocd-cmd-params-cm` patch
      (`server.insecure: "true"`, since Traefik terminates TLS at the
      edge) + `files/argocd-ingress.yaml`, confirmed live (`curl` returns
      `200` with the cert verified, no `-k` needed). `kubectl port-forward`
      still works as a fallback. Still need to: add the DNS record in the
      core repo (same manual cross-repo step as otel-demo's), and rotate
      the initial admin password.

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

- [x] `otel-demo` Application syncs — `kubectl -n otel-demo get pods` all
      `Running` (28/28), `kubectl -n argocd get applications` shows
      `otel-demo` as `Synced`/`Healthy`, confirmed live after PR #17
      merged (`2.1.1`). This cluster's 2-agent/4GB-each budget turned out
      sufficient for the full chart — no `Pending` pods, no need to trim
      `valuesObject`. Three components crash-looped on first sync, all
      the same root cause (these K3s nodes have no IPv6 stack at all) but
      two different mechanisms: `image-provider`/`telemetry-docs`
      (nginx, `listen [::]:PORT` baked into their `nginx.conf.template`)
      fixed via a `[::]`-stripped copy mounted over the original
      (PR #16); `flagd-ui` (Elixir/Phoenix sidecar, hardcoded
      `ip: {0,0,0,0,0,0,0,0}` in the compiled release's `runtime.exs`,
      not env-driven) fixed the same way — mounting a replacement file at
      the exact path its boot script re-evaluates from (PR #17).
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

- [x] Install the Kubernetes MCP and ArgoCD MCP servers, user scope
      (`kubernetes-mcp-server`, points at `~/.kube/config`; `argocd-mcp`
      by Akuity, needs `argocd account generate-token` — required
      enabling the `apiKey` capability on the `admin` account first,
      off by default). Both `claude mcp list` as Connected. `argocd-mcp`
      only works while a `kubectl port-forward svc/argocd-server 8080:443`
      is running, pending the DNS record below; repoint `ARGOCD_BASE_URL`
      at the real hostname once that's in place.
- [x] Expose the ArgoCD UI via Traefik too — see Phase 2's entry above
      (same work item, tracked there since it's really a Phase 2
      "green ArgoCD" concern).
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
