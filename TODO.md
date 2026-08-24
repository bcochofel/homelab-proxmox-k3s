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
      static IPs `192.168.68.40`-`.42` (re-IP'd from the original
      `.25`-`.27`, freed up by the core repo's proxy VM re-IP),
      inventory generated.
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
- [x] Switched the CNI from K3s' bundled Flannel + kube-proxy to Cilium
      (kube-proxy replacement, Hubble relay + UI) — new `cilium` role,
      `15-cilium.yml` playbook, `k3s_server`'s `INSTALL_K3S_EXEC` flags.
      See `CLAUDE.md`'s "Decisions that are deliberate". Confirmed live:
      `cilium status` all `OK` (DaemonSets `3/3`, 44/44 pods managed),
      `kubectl get nodes` all three `Ready`, `otel-demo`'s ~28 pods
      redistributed across all three nodes once agents joined. `k3s-srv1`
      bumped from 2 vCPU/4GB to 4 vCPU/8GB after a live resource-exhaustion
      incident during this rollout (load average ~25 on 2 vCPU, memory
      exhausted) — see `CLAUDE.md`'s topology-sizing note.
- [ ] Traefik's Cloudflare DNS-01 cert resolver needs
      `--certificatesresolvers.cloudflare.acme.dnschallenge.resolvers=
      1.1.1.1:53,8.8.8.8:53` (now in `helmchartconfig.yaml.j2` and applied
      live) because CoreDNS is authoritative for `homelab.bcochofel.com`
      and without it Traefik's ACME zone-cut walk never reaches the real
      `bcochofel.com` Cloudflare zone — see `docs/ARGOCD.md`'s Traefik
      section. `argocd.homelab.bcochofel.com` confirmed getting a real
      Let's Encrypt cert after the fix; `otel-demo`/`hubble` hit a DNS
      propagation timeout on the same attempt (not the zone-lookup bug —
      TXT records did get created, just didn't propagate to `1.1.1.1`/
      `8.8.8.8` before lego's check window closed). Needs a follow-up
      check that they succeed on Traefik's own retry, without forcing
      another `rollout restart` too soon and burning more of Let's
      Encrypt's per-domain failed-authorization rate limit.

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
      still works as a fallback. DNS record added in the core repo,
      confirmed resolving from `k3s-srv1` (CoreDNS/Pihole). Still need to
      rotate the initial admin password.

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
- [x] Superseded the PR #16/#17 app-level patches above: root-caused the
      crash loops to the Packer template's `ipv6.disable=1` GRUB flag
      (kernel IPv6 stack fully off, not just unaddressed). The template's
      `late-commands` no longer set that flag (kernel stays IPv6-capable,
      `dhcp6` stays `false` — no routable v6 address needed, apps just
      need `bind()` on `[::]` to succeed), and the `image-provider`/
      `telemetry-docs`/`flagd` overrides were reverted out of
      `otel-demo.yaml` (PR #19). Confirmed live after merge: ArgoCD synced
      fresh `image-provider`/`telemetry-docs`/`flagd` pods with no
      overrides, all `Running` with 0 restarts — `image-provider` serving
      real `200`s, `flagd-ui`'s log shows it bound the *unpatched*
      upstream `[::]:4000` (IPv6 wildcard) socket successfully, proving
      the kernel-level fix alone is sufficient without the app-level
      workarounds.
- [x] Confirm traces/metrics/logs actually land in Kibana's APM/
      Observability UI, not just that the collector's exporter didn't
      error — confirmed live via the Elastic MCP once its credentials
      were fixed: `traces-apm-default` (879K+ docs), `logs-apm.app.*`/
      `metrics-apm.app.*` data streams exist for every otel-demo service
      *and* general infra (Cilium, CoreDNS, Traefik, ArgoCD, Hubble,
      Elastic Agent itself) — the Kubernetes integration's OTel-native
      collection is capturing broad cluster observability, not just app
      traces.
- [ ] If pods are `Pending` on resource pressure: trim `otel-demo`'s
      `valuesObject` further (replica counts, resource requests) before
      reconsidering the node topology itself.
- [x] Add the DNS record for `otel-demo.homelab.bcochofel.com` (and
      `argocd.homelab.bcochofel.com`) to the **core repo's** `dns_hosts`,
      pointed at `k3s-srv1`/`192.168.68.40` — done, confirmed resolving
      from `k3s-srv1` itself. Traefik issued real Let's Encrypt certs for
      both (`openssl s_client` confirms `CN=Let's Encrypt` for each
      hostname, not the Traefik default self-signed cert).
- [x] Confirm browser-side traces actually arrive — validated indirectly:
      `otel-demo`'s own `load-generator` service continuously exercises
      the full checkout flow (11,111 `logs-apm.app.checkout-default`
      docs, real trace IDs tied to `PUBLIC_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`'s
      `/otlp-http/v1/traces` path through the frontend-proxy Ingress),
      confirming the endpoint override actually works end-to-end.
- [ ] Decide whether the apm-server endpoint needs auth/TLS added on the
      elastic repo's side, and if so, add the matching `Authorization`
      header (+ certificate trust) to `otel-demo.yaml`'s
      `otlphttp/elastic` exporter — see `docs/ARGOCD.md`.
- [x] Ship general K3s node/pod log collection to Elastic — Fleet-managed
      Elastic Agent (`argocd/apps/elastic-agent.yaml`,
      `argocd/apps/kube-state-metrics.yaml`, `elastic_agent_secret`
      Ansible role, `35-elastic-agent-secret.yml`) matching the
      core/elastic repos' pattern. See `CLAUDE.md`'s "Decisions that are
      deliberate". Confirmed live: `kubectl -n argocd get applications`
      both `Synced`/`Healthy`, all agent/kube-state-metrics pods
      `Running`, all three nodes enrolled/healthy in Kibana's Fleet
      Agents view. Two real bugs found and fixed along the way (see
      commits `b593bd5`/`017d13c`): `k3s-srv1` hitting kubelet
      `DiskPressure` (Packer template's LVM layout), and the
      elastic-agent chart's bundled `kube-state-metrics` dependency
      fighting the standalone `kube-state-metrics.yaml` app over
      resource ownership — the ownership fight was very likely also
      forcing the DaemonSet's rolling restarts that showed up as all
      three nodes flapping unhealthy in Fleet.
- [ ] Fleet-managed `elastic-agent` only runs the `perNode` preset —
      `agent.fleet.enabled: true` makes the chart's
      `elasticagent.init.fleet` helper disable every preset except
      whichever `agent.fleet.preset` names (default `perNode`), unlike
      standalone mode where `perNode`+`clusterWide` both ship by
      default. A second Application (same chart, `agent.fleet.preset:
      clusterWide`) is needed for cluster-wide state metrics — not yet
      added.
- [x] `checkout` flow: resolved. The synthetic `POST /api/checkout` `500`
      was the test's own incomplete payload failing app-level validation
      — confirmed via the actual APM error log entry
      (`logs-apm.error-default`, exact timestamp match): `"shipping
      quote failure: failed POST to email service: expected 200, got
      400"`. Not an infra bug — `otel-demo`'s own `load-generator`
      exercises the real checkout flow continuously and successfully
      (11,111 `logs-apm.app.checkout-default` docs); the two other
      checkout errors found in Elastic (`"Credit card info is
      invalid"`) are the demo's own intentional synthetic-failure
      traffic, not a regression.
- [x] Elastic MCP server auth fixed (was `401` on every query) —
      confirmed working, used to verify the APM data above.
- [x] Kubernetes/ArgoCD MCP servers reconfigured after the cluster
      recreation (new API server TLS cert, new ArgoCD admin token via
      `argocd account generate-token` — needed enabling the `apiKey`
      capability on the `admin` account first, `kubectl -n argocd patch
      configmap argocd-cm` with `accounts.admin: apiKey, login`, off by
      default). Both confirmed working after a `/mcp` reconnect.

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
- [ ] The Packer template's own LVM layout (`packer/ubuntu-26.04/http/
      user-data.yml.tpl`'s `storage:` section) needs the same fix
      eventually: it gives `/` only 25GB of the 50GB template disk,
      splitting the rest into `home`/`tmp`/`opt` this workload barely
      touches — root filled up (`k3s-srv1` hit kubelet `DiskPressure`,
      `agent1`/`agent2` trending the same way) well before the disk
      itself did. Worked around live for now with a second Terraform-
      provisioned disk per node (`extra_disk` on `k3s_server_nodes`/
      `k3s_agent_nodes`, added to each VM's volume group and root
      extended onto it) rather than reshuffling the existing LVs on
      running nodes. The elastic repo hit and fixed the same
      class of problem on its own template — worth checking how it
      solved it there before reinventing the layout here.
- [ ] The `extra_disk` fix above only provisions the second disk via
      Terraform — adding it to each node's volume group and extending
      `root` onto it (`pvcreate`/`vgextend`/`lvextend -l +100%FREE`/
      `resize2fs`, done live over SSH on all three nodes on 2026-08-16)
      was a **manual, one-off step, not automated anywhere**. If these
      VMs are ever destroyed/recreated again (like this session's earlier
      `terraform destroy`/`apply` for the Cilium switch), the new disk
      comes back but sits unpartitioned/unused until this is redone by
      hand. Either automate it (a new early `k3s_common`-stage Ansible
      task, idempotent — skip if the VG already has the extra PV) or
      make it moot by fixing the Packer template's LVM layout instead
      (see the item above) so a fresh template doesn't need the extra
      disk at all.
- [ ] The `elastic-agent` chart's Fleet-managed mode only runs **one**
      preset per Helm release (`elasticagent.init.fleet` disables every
      preset except whichever `agent.fleet.preset` names, default
      `perNode`) — unlike standalone mode, `perNode`+`clusterWide` don't
      both ship from a single release once `agent.fleet.enabled: true`.
      `argocd/apps/elastic-agent.yaml` currently only covers `perNode`
      (per-node logs/metrics); cluster-wide state metrics need a second
      Application (same chart, `agent.fleet.preset: clusterWide`) —
      not yet added.

## Phase 5 — SRE AI-autonomy: health alerting & investigation (parallel track, health/monitoring only — not infrastructure deployment)

Context: <https://sre.google/resources/practices-and-processes/ai-engineering-reliable-operations/>'s
five-stage AI-autonomy ladder (L0 Manual → L1 Assisted Automation → L2
Partial Autonomy (human approval) → L3 High Autonomy (bounded scenarios) →
L4 Full Autonomy). Same cross-repo initiative tracked in the elastic repo's
`TODO.md` Phase 6 — this repo's slice of it. Deliberately excludes
`packer`/`terraform`/`ansible` provisioning, which stays exactly as gated
today; this is about runtime cluster health only.

- [ ] Scope `kubernetes-mcp-server`/`argocd-mcp`/`proxmox` MCP credentials
      to genuinely read-only for unattended investigation use (mirror the
      elastic repo's `mcp@pve!mcp` least-privilege pattern) — today only
      Claude Code's own Bash `ask` list gates writes here, not the MCP tool
      calls themselves, which is not a safe boundary for an agent running
      without a human approving each call
- [ ] Feed node health (NotReady/DiskPressure/MemoryPressure), pod health
      (CrashLoopBackOff/ImagePullBackOff/OOMKilled), and ArgoCD app health
      (OutOfSync/Degraded) into the shared investigation runbook (elastic
      repo Phase 6)
- [ ] L3 candidates (only after L1/L2 proven elsewhere): node disk-pressure
      cleanup (prune old images, not a reboot — same class of problem as
      the `k3s-srv1` `DiskPressure` incident above, but automated and
      bounded this time), a bounded `kubectl scale` for a specific
      already-diagnosed recurring `CrashLoopBackOff` pattern. Explicitly
      scoped narrower than ArgoCD's own unscoped `selfHeal`, which is what
      caused the `k3s-srv1` resource-exhaustion incident this file already
      documents — L3 autonomy here must not repeat that mistake

See `CLAUDE.md` for the detailed technical notes and decisions behind each
of these (agent-facing context) — this file is just the status list.
