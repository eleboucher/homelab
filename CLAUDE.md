# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GitOps-managed Kubernetes homelab running a media server stack (Jellyfin, Sonarr, Radarr, etc.), home automation, and monitoring infrastructure. Two-node cluster using Talos Linux with Flux CD for GitOps.

**Stack:** Talos Linux → Kubernetes v1.35 → Flux CD → Helm/Kustomize

## Common Commands

All commands use `just` (task runner). Run `just -l` to list available commands.

### Bootstrap (initial cluster setup)
```bash
just bootstrap talos          # Install Talos on nodes
just bootstrap kube           # Bootstrap Kubernetes
just bootstrap kubeconfig     # Fetch kubeconfig
just bootstrap namespaces     # Apply namespaces
just bootstrap crds           # Apply CRDs via Helmfile
just bootstrap apps           # Sync Helmfile apps
```

### Kubernetes Operations
```bash
just kube apply-ks <ns> <ks>  # Apply local Flux Kustomization
just kube delete-ks <ns> <ks> # Delete local Flux Kustomization
just kube sync-git            # Sync GitRepositories
just kube sync-hr             # Sync HelmReleases
just kube sync-ks             # Sync Kustomizations
just kube sync-es             # Sync ExternalSecrets
just kube sync-oci            # Sync OCIRepositories
just kube node-shell <node>   # Shell into node
just kube browse-pvc <ns> <claim>  # Browse PVC contents
just kube prune-pods          # Clean up failed/pending/succeeded pods
just kube view-secret <ns> <secret>  # View decoded secret
```

### Talos Management
```bash
just talos apply-node <node>  # Apply Talos config to node
just talos render-config <node>   # Render Talos config (dry-run)
just talos reboot-node <node>     # Reboot node
just talos reset-node <node>      # Reset node (wipe)
just talos shutdown-node <node>   # Shutdown node
just talos upgrade-k8s <version>  # Upgrade Kubernetes version
just talos upgrade-node <node>    # Upgrade Talos on node
just talos gen-schematic-id       # Generate Talos Factory schematic
just talos download-image <ver> <schematic>  # Download Talos ISO
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
│   ├── kube-system/         # Cilium, CoreDNS, Longhorn, metrics
│   ├── media/               # Jellyfin, Sonarr, Radarr, Bazarr, Prowlarr
│   ├── monitoring/          # Prometheus, Grafana, VictoriaLogs
│   ├── network/             # Envoy Gateway, External DNS, Cloudflared
│   └── security/            # External Secrets
├── components/              # Reusable Kustomize components
│   ├── cnpg/                # CloudNative PG patches
│   ├── gpu/                 # GPU resource patches
│   ├── nfs-media/           # NFS media mount patches
│   └── sops/                # SOPS decryption patches
└── flux/cluster/cluster.yaml    # Master Kustomization

bootstrap/
├── helmfile.d/              # Helmfile for CRDs and core apps
└── secret.sops.yaml         # Encrypted bootstrap secrets

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
- `*.sops.yaml` - Encrypted secrets (if needed)

**Secrets:** Use SOPS with Age encryption. Config in `.sops.yaml`. Encrypt sensitive data in `*.sops.yaml` files.

**Templates:** Jinja2 templates (`.j2` files) processed with `minijinja-cli`. Used for Talos configs.

**GitOps Flow:** Push to repo → Flux detects changes → Reconciles cluster state

## Validation

Pre-commit hooks enforce:
- SOPS encryption validation
- Kubernetes schema validation (kubeconform)
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
