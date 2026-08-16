# ArgoCD — GitOps layer + OpenTelemetry demo

Fourth stage of the pipeline, and where it hands off from Ansible to
GitOps. Ansible's `argocd` role (see [`docs/ANSIBLE.md`](ANSIBLE.md))
installs ArgoCD and applies exactly one `Application` — after that, every
other app on this cluster is managed declaratively from this repo, not by
re-running Ansible.

## App-of-apps

```text
ansible (argocd role)
  -> applies argocd/root-app.yaml ("root" Application)
       -> watches argocd/apps/ in this repo (auto-sync, prune, self-heal)
            -> argocd/apps/otel-demo.yaml ("otel-demo" Application)
            -> (future apps: one new file each, nothing else to touch)
```

`argocd/root-app.yaml` is the only manifest Ansible ever applies directly.
It points ArgoCD's own `repoURL`/`path`/`targetRevision` back at this same
GitHub repo (`argocd/apps`, `main`), so the loop closes: commit a new
`Application` YAML under `argocd/apps/`, push, and ArgoCD picks it up on
its own within its default sync interval — no `ansible-playbook` or
`kubectl apply` needed for day-2 additions. This repo is public, so ArgoCD
needs no Git credential `Secret` to pull it.

## `otel-demo` — routed to the elastic repo, not the chart's bundled backends

`argocd/apps/otel-demo.yaml` deploys the upstream
`open-telemetry/opentelemetry-demo` Helm chart, but with `jaeger`,
`prometheus`, `opensearch`, and `grafana` all disabled and the
`opentelemetry-collector` sub-chart's exporters redirected to
`homelab-proxmox-elastic`'s apm-server VM (`192.168.68.34:8200`) instead.
This is deliberate, not a resource-saving shortcut alone: the three-repo
point of this whole setup is one shared Elastic Observability stack
(metrics, logs, and APM) rather than a second, parallel one living inside
K3s — see `CLAUDE.md`.

- **Why plain HTTP, no auth.** The elastic repo's Fleet-managed APM
  integration (`ansible/roles/fleet_bootstrap/tasks/main.yml` in that
  repo) configures only `host: "0.0.0.0:8200"` on the package policy — no
  `secret_token`, no TLS certificate. Confirmed by reading that repo's
  actual Ansible task, not assumed from Elastic's docs in general. If that
  ever changes, the `otlphttp/elastic` exporter in `otel-demo.yaml` needs
  a matching `Authorization` header (and the endpoint scheme needs to
  become `https`) — tracked in `TODO.md`.
- **Why the exporters are `null`-ed, not just left unreferenced.** Helm
  values merge maps key-by-key; simply not mentioning
  `otlp_grpc/jaeger`/`otlp_http/prometheus`/`opensearch` in the override
  would leave them defined in the merged config (inherited from the
  chart's own `values.yaml`) but unreferenced by any pipeline once the
  `service.pipelines.*.exporters` lists are overridden — and the OTel
  Collector refuses to start if a declared exporter isn't used by at least
  one pipeline. Setting each to `null` removes the key from the merged
  map entirely (standard Helm values-merge behavior), so nothing dangling
  is left.
- **Why this also lands basic cluster metrics in Elastic "for free."** The
  demo chart's `opentelemetry-collector` sub-chart runs as a `daemonset`
  with `hostMetrics`/`kubernetesAttributes`/`kubeletMetrics`/
  `clusterMetrics` presets already enabled by upstream default — those
  feed the same `metrics` pipeline the `otlphttp/elastic` exporter is now
  on. K3s node/cluster metrics should show up in Elastic alongside the
  demo app's own telemetry without any extra role or config here. This
  does **not** cover general pod log collection across the cluster (no
  `filelog`/log-collection preset is enabled) — only the demo services'
  own OTel SDK log export goes through the `logs` pipeline. Shipping every
  pod's logs (or the nodes' own system logs/metrics via a Fleet-managed
  Elastic Agent DaemonSet, matching the core/elastic repos' pattern more
  directly) is future work — see `TODO.md`.
- **Verify after first deploy, don't assume.** The demo chart moves fast
  (the version pinned here, `0.41.0`, was fetched live from
  `open-telemetry/opentelemetry-helm-charts` while writing this, not
  recalled from training data — check `gh api
  repos/open-telemetry/opentelemetry-helm-charts/releases` for anything
  newer before bumping). Confirm in Kibana's APM/Observability UI that
  traces/metrics/logs are actually arriving after the first sync, and
  check `kubectl -n otel-demo get pods` for anything stuck `Pending` —
  disabling jaeger/prometheus/opensearch/grafana helps the ~20 remaining
  demo pods fit this cluster's 2-agent/4GB-each budget, but that fit is
  untested against the real chart, not calculated from first principles.

## Traefik — TLS termination + routing for in-cluster Ingresses

K3s bundles Traefik as its default ingress controller — `k3s_server`
installs with no `--disable traefik`, so it's already running in
`kube-system` before Ansible's `traefik` role touches anything.
That role (see [`docs/ANSIBLE.md`](ANSIBLE.md)) configures it with a
Cloudflare DNS-01 cert resolver so it can issue real Let's Encrypt certs
for Ingresses in this cluster directly.

- **Traefik terminates its own TLS — it does not proxy through the core
  repo's Caddy.** Deliberate: this repo exists partly to build hands-on
  Kubernetes/ArgoCD skills, and running Traefik's own ACME setup (rather
  than treating it as a routing-only layer behind Caddy) is a more
  realistic ingress-controller setup to learn on. The trade-off is a
  second, independent ACME pipeline against the same `bcochofel.com`
  Cloudflare zone core's Caddy also uses — mitigated by using a separate,
  separately-scoped Cloudflare API token (see `docs/ANSIBLE.md`'s
  "Secrets" section), same least-privilege-per-consumer reasoning as
  every other token boundary in this homelab.
- **Configured via `HelmChartConfig`, not a second Traefik install.** K3s
  deploys its bundled addons (including Traefik) as `HelmChart` custom
  resources managed by its own built-in helm-controller. A
  `HelmChartConfig` resource with a matching `metadata.name`/`namespace`
  (`traefik`/`kube-system`) merges `spec.valuesContent` into that
  HelmChart's values and triggers a re-`helm upgrade` — this is the
  officially supported customization path for K3s addons, not a
  workaround. `ansible/roles/traefik/templates/helmchartconfig.yaml.j2`
  sets `additionalArguments` (the `certificatesresolvers.cloudflare.*`
  static-config flags Traefik's CLI/config expects), an `env` entry
  wiring `CF_DNS_API_TOKEN` from the `kube-system` Secret the same role
  creates, and `persistence.enabled: true` so `acme.json` (the issued
  certs) survives a pod restart.
- **DNS-01 zone-cut discovery needs public resolvers, not this cluster's
  own.** CoreDNS is authoritative for `homelab.bcochofel.com` (the
  `nameserver` these VMs themselves use, `terraform/variables.tf`), so
  without `--certificatesresolvers.cloudflare.acme.dnschallenge.resolvers=
  1.1.1.1:53,8.8.8.8:53` in the `HelmChartConfig`'s `additionalArguments`,
  Traefik's ACME zone-cut walk gets a real (internal) SOA answer for
  `homelab.bcochofel.com` and never continues up to the actual Cloudflare
  zone, `bcochofel.com` — fails with `"zone could not be found"`. Same
  root cause and same fix as the core repo's Caddy (its Caddyfile has an
  identical `resolvers` line, hit there 2026-08-15); hit here 2026-08-16
  after `terraform destroy`/`apply` wiped `k3s-srv1`'s local-path-backed
  `acme.json` and forced every hostname to re-request from scratch.
- **Unverified, flag before trusting blindly:** the exact
  `additionalArguments`/`env`/`persistence` values keys assume the
  Traefik Helm chart shape K3s v1.36.3+k3s1 vendors follows the
  widely-documented upstream `traefik/traefik-helm-chart` values schema.
  This wasn't confirmed against that exact vendored chart version's
  `values.yaml` — verify with `kubectl -n kube-system get helmchart
  traefik -o yaml` (or check the chart bundled in
  `/var/lib/rancher/k3s/server/static/charts/` on the server node) before
  assuming a failed apply is a typo elsewhere. Tracked in `TODO.md`.
- **DNS is a manual, cross-repo step.** `otel-demo.homelab.bcochofel.com`,
  `argocd.homelab.bcochofel.com`, `hubble.homelab.bcochofel.com` (and any
  future Traefik-fronted hostname) each need a DNS record pointed at
  a K3s node IP — `k3s-srv1` (`192.168.68.40`) is the documented default,
  since K3s' bundled ServiceLB (Klipper) exposes the Traefik `LoadBalancer`
  Service's ports on every schedulable node's own IP, not a single
  cluster-wide virtual IP. Add the entry to the **core repo's**
  `ansible/inventory/group_vars/dns.yml` `dns_hosts` list (its CoreDNS +
  Pihole are this whole homelab's resolvers) — not automated from here,
  same "manual cutover" pattern that repo's own README already documents
  for its own DNS entries.

## `otel-demo`'s Ingress — the frontend-proxy component, and one env override

`argocd/apps/otel-demo.yaml`'s `components.frontend-proxy.ingress` block
is what actually exposes the demo through Traefik — **`frontend-proxy`,
not `frontend`**, is the chart's real entry point: it fronts the Next.js
frontend service *and* reverse-proxies `/otlp-http/*` to the collector, so
the browser can send its own traces without a CORS workaround. The
`ingressClassName: traefik` + `traefik.ingress.kubernetes.io/router.tls*`
annotations tell Traefik's Kubernetes Ingress provider to terminate TLS
using the `cloudflare` cert resolver configured above, rather than reading
a cert from a Kubernetes `Secret` the way `cert-manager`-style setups do —
no `secretName` is set in the Ingress `tls:` block for exactly that reason.

The chart's own default for `PUBLIC_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`
(the `frontend` component's env, read by browser-side JS) is
`http://localhost:8080/otlp-http/v1/traces` — correct only when accessing
the demo via `kubectl port-forward`. With real Ingress access, that value
has to be overridden to the actual public hostname
(`https://otel-demo.homelab.bcochofel.com/otlp-http/v1/traces`, set via
`components.frontend.envOverrides`) or browser-emitted traces silently
vanish — the browser would try posting to its own `localhost:8080`, not
this cluster, and nothing surfaces an error for it.

## Day-2: adding another app

1. Write a new `Application` manifest under `argocd/apps/` (copy
   `otel-demo.yaml`'s shape as a starting point — `destination.namespace`,
   `syncPolicy.automated`, `CreateNamespace=true` if it needs a fresh
   namespace).
2. Commit and push to `main`.
3. ArgoCD's `root` Application picks it up on its own next sync cycle — no
   Ansible re-run needed. Watch it land with `kubectl -n argocd get
   applications` or the ArgoCD UI (`kubectl -n argocd port-forward
   svc/argocd-server 8080:443`, default admin password in the
   `argocd-initial-admin-secret` Secret in the `argocd` namespace until
   it's rotated).

## Versions

`argocd_version` (ArgoCD's own install manifest tag) lives in
`ansible/inventory/group_vars/all.yml`, hand-authored — bump it there, not
in the `argocd` role itself. The `otel-demo` chart's `targetRevision`
lives in `argocd/apps/otel-demo.yaml` directly, since ArgoCD (not Ansible)
is what actually reads it.
