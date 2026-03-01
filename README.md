# Mediaserver K8s

[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.erwanleboucher.dev%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=white&color=blue&label=%20)](https://talos.dev)&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.erwanleboucher.dev%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.erwanleboucher.dev%2Fflux_version&style=for-the-badge&logo=flux&logoColor=white&color=blue&label=%20)](https://fluxcd.io)

[![Age-Days](https://kromgo.erwanleboucher.dev/cluster_age_days?format=badge)](https://github.com/kashalls/kromgo/)&nbsp;
[![Node-Count](https://kromgo.erwanleboucher.dev/cluster_node_count?format=badge)](https://github.com/kashalls/kromgo/)&nbsp;
[![Alerts](https://kromgo.erwanleboucher.dev/cluster_alert_count?format=badge)](https://github.com/kashalls/kromgo/)&nbsp;
[![Pod-Count](https://kromgo.erwanleboucher.dev/cluster_pod_count?format=badge)](https://github.com/kashalls/kromgo/)&nbsp;
[![CPU-Usage](https://kromgo.erwanleboucher.dev/cluster_cpu_usage?format=badge)](https://github.com/kashalls/kromgo/)&nbsp;
[![Memory-Usage](https://kromgo.erwanleboucher.dev/cluster_memory_usage?format=badge)](https://github.com/kashalls/kromgo/)


GitOps-managed Kubernetes homelab running a media server stack, home automation, and observability infrastructure using Flux.

## Cluster Nodes

| Node         | OS                  | Hardware          | CPU                  | RAM  | Role          | Storage                        |
| ------------ | ------------------- | ----------------- | -------------------- | ---- | ------------- | ------------------------------ |
| **kharkiv**  | Talos               | Intel i5 12th Gen | 8 cores / 16 threads | 32GB | Control Plane | USB Hard Drives (`/srv/media`) |
| **le-havre** | Talos in Proxmox VM | Intel N150        | 4 cores              | 32GB | Worker        | -                              |

