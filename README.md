# Mediaserver K8s

GitOps-managed Kubernetes homelab running a media server stack, home automation, and monitoring infrastructure using Flux.

## Cluster Nodes

| Node         | OS                  | Hardware          | CPU                  | RAM  | Role          | Storage                        |
| ------------ | ------------------- | ----------------- | -------------------- | ---- | ------------- | ------------------------------ |
| **kharkiv**  | Talos               | Intel i5 12th Gen | 8 cores / 16 threads | 16GB | Control Plane | USB Hard Drives (`/srv/media`) |
| **le-havre** | Talos in Proxmox VM | Intel N150        | 4 cores              | 16GB | Worker        | -                              |

May the lord of ram make it cheaper
