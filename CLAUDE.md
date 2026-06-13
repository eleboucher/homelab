# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GitOps-managed Kubernetes homelab running a media server stack (Jellyfin, Sonarr, Radarr, etc.), home automation, and observability infrastructure. Two-node cluster using Talos Linux with Flux CD for GitOps.

**Stack:** Talos Linux → Kubernetes v1.35 → Flux CD → Helm/Kustomize

## Common Commands

All commands use `just` (task runner). Run `just -l` to list available commands.

### Bootstrap (initial cluster setup)

```bash
just bootstrap cluster        # Run full bootstrap end-to-end
just bootstrap apply          # topf apply --auto-bootstrap (config all nodes + bootstrap etcd)
just bootstrap credentials    # Generate talosconfig + kubeconfig
just bootstrap base           # Wait for nodes, apply bootstrap kustomize + CRDs
just bootstrap apps           # Sync Helmfile apps
```

### Kubernetes Operations

```bash
just kube apply-ks <ns> <ks>  # Apply local Flux Kustomization
just kube delete-ks <ns> <ks> # Delete local Flux Kustomization
just kube sync <resource>     # Sync a Flux resource (hr|ks|gitrepo|ocirepo|es); optionally pass <ns> <name>
just kube node-shell <node>   # Shell into node
just kube browse-pvc <ns> <claim>  # Browse PVC contents
just kube prune-pods          # Clean up failed/pending/succeeded pods
just kube view-secret <ns> <secret>  # View decoded secret
```

### Talos Management

Talos config is managed with [topf](https://github.com/postfinance/topf); recipes wrap it.

```bash
just talos nodes              # List nodes and their live state
just talos diff               # Pending config diff vs live cluster (topf dry-run)
just talos render [out]       # Render all machine configs to a directory
just talos render-config <node>   # Render and print one node's machine config
just talos apply-node <node>  # Apply Talos config to a node (topf apply)
just talos upgrade-node <node>    # Upgrade Talos on node to topf.yaml version
just talos upgrade-k8s <version>  # Upgrade Kubernetes (via talosctl; not topf)
just talos reboot-node <node>     # Reboot node
just talos reset-node <node>      # Reset node (wipe)
just talos shutdown-node <node>   # Shutdown node
just talos kubeconfig         # Fetch kubeconfig + talosconfig, restart controllers
just talos schematic-id       # Print the resolved Talos Factory schematic ID
just talos download-image <ver>   # Download Talos ISO
```

## Architecture

```
kubernetes/
├── apps/                    # Application deployments by category
│   ├── automation/          # Renovate operator
│   ├── cert-manager/        # TLS certificates
│   ├── database/            # CloudNative PostgreSQL
│   ├── downloads/           # qBittorrent, SABnzbd, Autobrr
│   ├── flux-system/         # Flux controllers
│   ├── kube-system/         # Cilium, CoreDNS,  metrics
│   ├── media/               # Jellyfin, Sonarr, Radarr, Bazarr, Prowlarr
│   ├── observability/          # Prometheus, Grafana, VictoriaLogs
│   ├── network/             # Envoy Gateway, External DNS, Cloudflared
│   └── security/            # External Secrets
├── components/              # Reusable Kustomize components
│   ├── cnpg/                # CloudNative PG patches
│   ├── gpu/                 # GPU resource patches
│   ├── nfs-media/           # NFS media mount patches
└── flux/cluster/cluster.yaml    # Master Kustomization

bootstrap/
├── helmfile/                # Helmfile for CRDs and core apps
├── kustomize/               # Bootstrap manifests (namespaces, secrets) applied before Flux

talos/                       # Talos cluster config, managed with topf
├── topf.yaml                # Cluster identity (name, endpoint, versions) + node list
├── secrets.yaml             # Talos PKI bundle (ref+op:// → 1Password, vals-resolved)
├── schematic.yaml           # Talos Factory schematic (extensions, kernel args)
├── all/                     # Patches applied to every node
├── control-plane/           # Patches applied to control-plane nodes
├── worker/                  # Patches applied to worker nodes
└── node/<host>/             # Per-node patches (paris, kharkiv)
```

## Key Patterns

**App Structure:** Each app in `kubernetes/apps/` typically has:

- `kustomization.yaml` - Kustomize config
- `ks.yaml` - Flux Kustomization CRD
- `helmrelease.yaml` - Helm release config
- `ocirepository.yaml` - OCI chart source
- `externalsecret.yaml` - External Secret config (if needed)

**Secrets:** Use 1Password + External Secrets for all secrets. Store credentials in 1Password vault, sync to Kubernetes with External Secrets.

**Talos config (topf):** `talos/topf.yaml` declares the cluster + nodes; layered strategic-merge patches under `all/`, `control-plane/`, `worker/`, `node/<host>/` build each machine config (applied in that order). PKI lives in `talos/secrets.yaml` as `ref+op://` references resolved via `vals`/1Password at apply time — so `op` must be authenticated when topf runs. Preview changes with `just talos diff` before `just talos apply-node <node>`.

**Templates:** Jinja2 templates (`.j2` files) processed with `minijinja-cli` (via the `just template` recipe). Used for bootstrap secret injection (the Talos layer no longer uses Jinja).

**GitOps Flow:** Push to repo → Flux detects changes → Reconciles cluster state

## Validation

Pre-commit hooks enforce:

- YAML schema validation (kubeconform)
- YAML linting and formatting

## YAML Sorting Rules

### General Rules (all YAML files)

Default: Sort all fields alphabetically unless overridden below.

**Kubernetes resource ordering:**

1. `apiVersion`
2. `kind`
3. `metadata`
4. `spec`

**Metadata section ordering:**

1. `name`
2. `namespace`
3. `annotations`
4. `labels`

### HelmRelease Files (app-template based)

Applies to HelmReleases using `oci://ghcr.io/bjw-s-labs/helm/app-template` (identified by sidecar `ocirepository.yaml`).

**`enabled` field:** Always first within its section.

**`spec` section ordering:**

1. `chartRef`
2. `interval`
3. `dependsOn`
4. `install`
5. `upgrade`
6. `values`

**`spec.values` ordering:**

1. `defaultPodOptions`
2. Other fields alphabetically

**`spec.values.controllers.*` ordering:**

1. `pod`
2. Other fields alphabetically
3. `initContainers`
4. `containers`

**`spec.values.controllers.*.containers.*` ordering:**

1. `image`
2. Other fields alphabetically

**`resources` sections ordering:**

1. `requests`
2. `limits`

**`spec.values.service.*` ordering:**

1. `type`
2. Other fields alphabetically

**`persistence.*` ordering:**

1. `type`
2. Other fields alphabetically
3. `globalMounts`
4. `advancedMounts`
