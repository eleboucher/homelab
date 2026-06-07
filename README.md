<div align="center">

# homelab K8s

### 🏠 A GitOps-managed Homelab

_Powered by [Talos](https://talos.dev), [Flux](https://fluxcd.io), and [Kubernetes](https://kubernetes.io)_

<br />

[![Talos](https://kromgo.erwanleboucher.dev/badges/talos_version)](https://talos.dev)
[![Kubernetes](https://kromgo.erwanleboucher.dev/badges/kubernetes_version)](https://kubernetes.io)
[![Flux](https://kromgo.erwanleboucher.dev/badges/flux_version)](https://fluxcd.io)

<p align="center">
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.erwanleboucher.dev/badges/cluster_age_days" alt="Age"></a>
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.erwanleboucher.dev/badges/cluster_node_count" alt="Nodes"></a>
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.erwanleboucher.dev/badges/cluster_pod_count" alt="Pods"></a>
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.erwanleboucher.dev/badges/cluster_alert_count" alt="Alerts"></a>
  <br />
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.erwanleboucher.dev/badges/cluster_cpu_usage" alt="CPU"></a>
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.erwanleboucher.dev/badges/cluster_memory_usage" alt="Memory"></a>
</p>

</div>

---

## 📖 Overview

This repository hosts the Infrastructure as Code (IaC) for my Kubernetes homelab. It runs a media server stack, home automation, and observability infrastructure.

The cluster is built on **Talos Linux**, an immutable and minimal OS, and managed via **GitOps** principles using **Flux**. Changes pushed to this repository are automatically reconciled in the cluster.

---

## ⚙️ Hardware

My cluster is a hybrid setup running on bare metal and virtualized nodes.

| Node        | OS          | Hardware          | Specs           | Role            | Storage                                                            |
| :---------- | :---------- | :---------------- | :-------------- | :-------------- | :----------------------------------------------------------------- |
| **kharkiv** | Talos Linux | Intel i5 12th Gen | 8C / 16T / 47GB | `worker`        |                                                                    |
| **paris**   | Talos Linux | AMD Ryzen 5 5600X | 6C / 12T / 48GB | `control-plane` | 256GB NVMe (system) + Samsung MZ7KM1T9 SSD (ZFS) + SATA media disk |

---

## 🧩 Core Components

| Component                                            | Description                                      | Namespace      |
| :--------------------------------------------------- | :----------------------------------------------- | :------------- |
| **[Cilium](https://cilium.io/)**                     | CNI, Network Policies, and Load Balancing.       | `kube-system`  |
| **[Cert-Manager](https://cert-manager.io/)**         | Automates Let's Encrypt SSL certificates.        | `cert-manager` |
| **[External Secrets](https://external-secrets.io/)** | Syncs secrets from 1Password into the cluster.   | `security`     |
| **[Gateway API](https://gateway-api.sigs.k8s.io/)**  | Modern ingress management via **Envoy Gateway**. | `network`      |

---

## 🚀 Services & Applications

Key user-facing applications running on the cluster.

| Category          | Applications                                                                                                                                                                                                          |
| :---------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Media**         | [Jellyfin](https://jellyfin.org/), [Sonarr](https://sonarr.tv/), [Radarr](https://radarr.video/), [Bazarr](https://www.bazarr.media/), [Prowlarr](https://prowlarr.com), [Seerr](https://github.com/seerr-team/seerr) |
| **Observability** | [Grafana](https://grafana.com/), [Prometheus](https://prometheus.io/), [VictoriaLogs](https://docs.victoriametrics.com/victorialogs/), [Gatus](https://gatus.io)                                                      |
| **IOT**           | [Home Assistant](https://www.home-assistant.io/)                                                                                                                                                                      |

---

Huge thanks to [@onedr0p](https://github.com/onedr0p) and the amazing [Home Operations](https://discord.gg/home-operations) Discord community for their knowledge and support. If you're looking for inspiration, check out [kubesearch.dev](https://kubesearch.dev) to discover how others are deploying applications in their homelabs.</sub>
