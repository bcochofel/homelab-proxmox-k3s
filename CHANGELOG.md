# 📦 Changelog

All notable changes to this infrastructure project will be documented here.

# [2.3.0](https://github.com/bcochofel/homelab-proxmox-k3s/compare/2.2.0...2.3.0) (2026-08-16)


### Features

* **ansible,argocd:** deploy Elastic Agent (Fleet-managed) + kube-state-metrics ([5b69444](https://github.com/bcochofel/homelab-proxmox-k3s/commit/5b69444a71cf8ee1f589d34c46686f20c6f606fd))

# [2.2.0](https://github.com/bcochofel/homelab-proxmox-k3s/compare/2.1.1...2.2.0) (2026-08-16)


### Bug Fixes

* **otel-demo,packer:** root-cause IPv6 crash loops via kernel flag, not app patches ([e794ce2](https://github.com/bcochofel/homelab-proxmox-k3s/commit/e794ce2df774c705d155388ee781b334828e77e9)), closes [16/#17](https://github.com/bcochofel/homelab-proxmox-k3s/issues/17)
* **release:** switch changelog preset from conventionalcommits to angular ([f4b9799](https://github.com/bcochofel/homelab-proxmox-k3s/commit/f4b97991dacce364674b23bc2cd5b0341f4d4730))
* **traefik:** point ACME DNS-01 zone lookup at public resolvers ([c0c3220](https://github.com/bcochofel/homelab-proxmox-k3s/commit/c0c3220a2c58618fd3c52496e791af8c113e4d18))


### Features

* **ansible:** switch K3s CNI from Flannel/kube-proxy to Cilium ([67e99ae](https://github.com/bcochofel/homelab-proxmox-k3s/commit/67e99ae1c1a4790eba4e713543561c8d07b68d44))

## [2.1.1](https://github.com/bcochofel/homelab-proxmox-k3s/compare/2.1.0...2.1.1) (2026-08-13)

### Bug Fixes

* **otel-demo:** stop flagd-ui crash-looping on IPv6-less nodes ([a077a24](https://github.com/bcochofel/homelab-proxmox-k3s/commit/a077a24b41058761359e506b31ed7db492710161))
* **release:** use valid semver prerelease identifiers for branches ([1b3f97e](https://github.com/bcochofel/homelab-proxmox-k3s/commit/1b3f97e399d90cb28c80bc1e166528f233703063)), closes [#15](https://github.com/bcochofel/homelab-proxmox-k3s/issues/15)

## [2.1.0](https://github.com/bcochofel/homelab-proxmox-k3s/compare/2.0.0...2.1.0) (2026-08-13)

### Bug Fixes

* **otel-demo:** stop image-provider/telemetry-docs crash-looping ([7f46294](https://github.com/bcochofel/homelab-proxmox-k3s/commit/7f46294bc5a8138781d63ceb3ed4076c523bcd03))

### Features

* **argocd:** expose ArgoCD UI via Traefik, pin argocd CLI ([d60968e](https://github.com/bcochofel/homelab-proxmox-k3s/commit/d60968e0b6c8979edc9596ccdc00a5cdde1cda9c))

## [2.0.0](https://github.com/bcochofel/homelab-proxmox-k3s/compare/1.2.0...2.0.0) (2026-08-13)

### Features

* rewrite K3s pipeline onto bpg/proxmox, add ArgoCD GitOps + Traefik ([3472c6d](https://github.com/bcochofel/homelab-proxmox-k3s/commit/3472c6dc02f6bbb5449dff35548456e5481b2019))

### BREAKING CHANGES

* the Terraform provider changes from Telmate/proxmox to
bpg/proxmox, and the root-level proxmox_vm_qemu/random_pet resources are
replaced by the shared modules/vm module. Any existing Terraform state
from the old layout is incompatible with this config — applied here
against a fresh HCP Terraform workspace (k3s-cluster), not migrated.
Variable shapes in terraform/variables.tf and the generated Ansible
inventory format changed too.

# Changelog

All notable changes to this project will be documented in this file. See
[Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## [1.2.0](https://github.com/bcochofel/homelab-proxmox-k3s/compare/1.1.0...1.2.0) (2025-11-17)

### Features

* **terraform:** Removed Servers ([011d569](https://github.com/bcochofel/homelab-proxmox-k3s/commit/011d56975c81a4ea9a4ceaa8552c8e30113d5a3a))

## [1.1.0](https://github.com/bcochofel/homelab-proxmox-k3s/compare/1.0.1...1.1.0) (2024-10-25)

### Features

* New IP range for VMs ([704ad55](https://github.com/bcochofel/homelab-proxmox-k3s/commit/704ad55605fe33346672b48f8d0129550d63cc4f))

## [1.0.1](https://github.com/bcochofel/homelab-proxmox-k3s/compare/1.0.0...1.0.1) (2024-10-24)

### Bug Fixes

* Create K3s Servers and Agents ([c1b8a4b](https://github.com/bcochofel/homelab-proxmox-k3s/commit/c1b8a4bc966c5d8c8cb7b57108488386a5acdf87))

## 1.0.0 (2024-10-24)

### Features

* Added terraform code to create K3s Servers and Agents ([f3e6f84](https://github.com/bcochofel/homelab-proxmox-k3s/commit/f3e6f84e601553b54b5b257a62f321c2a8d52bdb))
* Added terraform code to create K3s Servers and Agents ([42f29a4](https://github.com/bcochofel/homelab-proxmox-k3s/commit/42f29a45e710929880bd1eef0f7cd010689c462b))
