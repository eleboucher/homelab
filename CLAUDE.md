# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GitOps-managed Kubernetes homelab running a media server stack (Jellyfin, Sonarr, Radarr, etc.), home automation, and observability infrastructure. Two-node cluster using Talos Linux with Flux CD for GitOps.

**Stack:** Talos Linux → Kubernetes v1.35 → Flux CD → Helm/Kustomize

## Common Commands

All commands use `mise` (task runner, experimental monorepo mode). Requires `MISE_EXPERIMENTAL=1` (or set in shell). Run `mise tasks --all` to list everything; `mise tasks` from a subdir lists that config_root's tasks.

Task path syntax: `mise run //<config_root>:<task> [args...]`. Inside a subdir, `mise run :<task>` also works.

### Bootstrap (initial cluster setup)
```bash
mise run //bootstrap:cluster        # Run full bootstrap end-to-end
mise run //bootstrap:nodes          # Install Talos on nodes
mise run //bootstrap:k8s            # Bootstrap Kubernetes
mise run //bootstrap:kubeconfig     # Fetch kubeconfig
mise run //bootstrap:base           # Wait for nodes, apply bootstrap kustomize + CRDs
mise run //bootstrap:apps           # Sync Helmfile apps
```

### Kubernetes Operations
```bash
mise run //kubernetes:apply-ks <ns> <ks>  # Apply local Flux Kustomization
mise run //kubernetes:delete-ks <ns> <ks> # Delete local Flux Kustomization
mise run //kubernetes:sync-git            # Sync GitRepositories
mise run //kubernetes:sync-hr             # Sync HelmReleases
mise run //kubernetes:sync-ks             # Sync Kustomizations
mise run //kubernetes:sync-es             # Sync ExternalSecrets
mise run //kubernetes:sync-oci            # Sync OCIRepositories
mise run //kubernetes:node-shell <node>   # Shell into node
mise run //kubernetes:browse-pvc <ns> <claim>  # Browse PVC contents
mise run //kubernetes:prune-pods          # Clean up failed/pending/succeeded pods
mise run //kubernetes:view-secret <ns> <secret>  # View decoded secret
```

### Talos Management
```bash
mise run //talos:apply-node <node>  # Apply Talos config to node
mise run //talos:render-config <node>   # Render Talos config (dry-run)
mise run //talos:reboot-node <node>     # Reboot node
mise run //talos:reset-node <node>      # Reset node (wipe)
mise run //talos:shutdown-node <node>   # Shutdown node
mise run //talos:upgrade-k8s <version>  # Upgrade Kubernetes version
mise run //talos:upgrade-node <node>    # Upgrade Talos on node
mise run //talos:download-image <ver>   # Download Talos ISO
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

talos/
├── machineconfig.yaml.j2    # Base Talos machine config (Jinja2)
├── schematic.yaml.j2        # Talos Factory schematic
└── nodes/                   # Per-node Talos configs
```

## Key Patterns

**App Structure:** Each app in `kubernetes/apps/` typically has:
- `kustomization.yaml` - Kustomize config
- `ks.yaml` - Flux Kustomization CRD
- `helmrelease.yaml` - Helm release config
- `ocirepository.yaml` - OCI chart source
- `externalsecret.yaml` - External Secret config (if needed)

**Secrets:** Use 1Password + External Secrets for all secrets. Store credentials in 1Password vault, sync to Kubernetes with External Secrets.

**Templates:** Jinja2 templates (`.j2` files) processed with `minijinja-cli`. Used for Talos configs.

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
