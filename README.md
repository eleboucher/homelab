<div align="center">

# homelab K8s

### 🏠 A GitOps-managed Homelab

_Powered by [Talos](https://talos.dev), [Flux](https://fluxcd.io), and [Kubernetes](https://kubernetes.io)_

<br />

[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.erwanleboucher.dev%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=white&color=blue&label=%20)](https://talos.dev)
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.erwanleboucher.dev%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://kubernetes.io)
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.erwanleboucher.dev%2Fflux_version&style=for-the-badge&logo=flux&logoColor=white&color=blue&label=%20)](https://fluxcd.io)

<p align="center">
  <a href="https://github.com/kashalls/kromgo/"><img src="https://kromgo.erwanleboucher.dev/cluster_age_days?format=badge&label=Age" alt="Age"></a>
  <a href="https://github.com/kashalls/kromgo/"><img src="https://kromgo.erwanleboucher.dev/cluster_node_count?format=badge&label=Nodes" alt="Nodes"></a>
  <a href="https://github.com/kashalls/kromgo/"><img src="https://kromgo.erwanleboucher.dev/cluster_pod_count?format=badge&label=Pods" alt="Pods"></a>
  <a href="https://github.com/kashalls/kromgo/"><img src="https://kromgo.erwanleboucher.dev/cluster_alert_count?format=badge&label=Alerts" alt="Alerts"></a>
  <br />
  <a href="https://github.com/kashalls/kromgo/"><img src="https://kromgo.erwanleboucher.dev/cluster_cpu_usage?format=badge&label=CPU" alt="CPU"></a>
  <a href="https://github.com/kashalls/kromgo/"><img src="https://kromgo.erwanleboucher.dev/cluster_memory_usage?format=badge&label=Memory" alt="Memory"></a>
</p>

</div>

---

## 📖 Overview

This repository hosts the Infrastructure as Code (IaC) for my Kubernetes homelab. It runs a media server stack, home automation, and observability infrastructure. 

The cluster is built on **Talos Linux**, an immutable and minimal OS, and managed via **GitOps** principles using **Flux**. Changes pushed to this repository are automatically reconciled in the cluster.

---

## ⚙️ Hardware

My cluster is a hybrid setup running on bare metal and virtualized nodes.

| Node | OS | Hardware | Specs | Role | Storage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **kharkiv** | Talos Linux | Intel i5 12th Gen | 8C / 16T / 32GB | `control-plane` | USB HDD (`/srv/media`) |
| **le-havre**| Talos (Proxmox) | Intel N150 | 4C / 4T / 32GB | `worker` | - |

---
## 🧩 Core Components

| Component | Description | Namespace |
| :--- | :--- | :--- |
| **[Cilium](https://cilium.io/)** | CNI, Network Policies, and Load Balancing. | `kube-system` |
| **[Cert-Manager](https://cert-manager.io/)** | Automates Let's Encrypt SSL certificates. | `cert-manager` |
| **[External Secrets](https://external-secrets.io/)** | Syncs secrets from 1Password into the cluster. | `security` |
| **[Gateway API](https://gateway-api.sigs.k8s.io/)** | Modern ingress management via **Envoy Gateway**. | `network` |
| **[Longhorn](https://longhorn.io/)** | Distributed block storage for persistent volumes. | `longhorn-system` |

---

## 🚀 Services & Applications

Key user-facing applications running on the cluster.

| Category | Applications |
| :--- | :--- |
| **Media** | [Jellyfin](https://jellyfin.org/), [Sonarr](https://sonarr.tv/), [Radarr](https://radarr.video/), [Bazarr](https://www.bazarr.media/), [Prowlarr](https://prowlarr.com), [Seerr](https://github.com/seerr-team/seerr) |
| **Observability** | [Grafana](https://grafana.com/), [Prometheus](https://prometheus.io/), [VictoriaLogs](https://docs.victoriametrics.com/victorialogs/), [Gatus](https://gatus.io)|
| **IOT** | [Home Assistant](https://www.home-assistant.io/) |

---

Huge thanks to [@onedr0p](https://github.com/onedr0p) and the amazing [Home Operations](https://discord.gg/home-operations) Discord community for their knowledge and support. If you're looking for inspiration, check out [kubesearch.dev](https://kubesearch.dev) to discover how others are deploying applications in their homelabs.</sub>
