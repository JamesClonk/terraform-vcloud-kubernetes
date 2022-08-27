# terraform-vcloud-kubernetes

[![Build](https://img.shields.io/github/workflow/status/JamesClonk/terraform-vcloud-kubernetes/Update?label=Build)](https://github.com/JamesClonk/terraform-vcloud-kubernetes/actions/workflows/update.yml)
[![License](https://img.shields.io/badge/License-Apache--2.0-lightgrey)](https://github.com/JamesClonk/terraform-vcloud-kubernetes/blob/master/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Kubernetes-blue)](https://kubernetes.io/)
[![IaC](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)

Deploy a Kubernetes cluster on vCloud / [Swisscom DCS+](https://dcsguide.scapp.swisscom.com/)

## Kubernetes cluster with k3s

### Architecture
![DCS+ Kubernetes Architecture](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_k8s.png)

### Components on cluster

| Component | Type | Description |
| --- | --- | --- |
| [Longhorn](https://longhorn.io/) | Storage | Highly available persistent storage for Kubernetes, provides cloud-native block storage with backup functionality |
| [Ingress NGINX](https://kubernetes.github.io/ingress-nginx/) | Routing | Provides HTTP traffic routing, load balancing, SSL termination and name-based virtual hosting |
| [Cert Manager](https://cert-manager.io/) | Certificates | Cloud-native, automated TLS certificate management and [Let's Encrypt](https://letsencrypt.org/) integration for Kubernetes |
| [Hairpin Proxy](https://github.com/compumike/hairpin-proxy) | Proxy | PROXY protocol support for internal-to-LoadBalancer traffic for Kubernetes Ingresses, specifically for passing cert-manager self-checks |
| [Kubernetes Dashboard](https://github.com/kubernetes/dashboard) | Dashboard | A general purpose, web-based UI for Kubernetes clusters that allows users to manage and troubleshoot applications on the cluster, as well as manage the cluster itself |
| [Prometheus](https://prometheus.io/) | Metrics | An open-source systems monitoring and alerting platform, collects and stores metrics in a time series database |
| [Loki](https://grafana.com/oss/loki/) | Logs | A horizontally scalable, highly available log aggregation and storage system |
| [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/) | Logs | An agent which collects and ships the contents of logs on Kubernetes into the Loki log storage |
| [Grafana](https://grafana.com/oss/grafana/) | Dashboard | Allows you to query, visualize, alert on and understand all of your Kubernetes metrics and logs |

## Installation

### Requirements

To use this Terraform module you will need to have a valid account / contract number on [Swisscom DCS+](https://dcsguide.scapp.swisscom.com/).

Configure your contract number (PRO-number) in `terraform.tfvars -> vcd_org`.

#### DCS+ resources

For deploying a Kubernetes cluster on DCS+ you will need to manually created the following resources first before you can proceed:
- a VCD / Dynamic Data Center (DDC)
- an Edge Gateway with Internet in your VCD/DDC
- an API User

##### Dynamic Data Center

Login to the DCS+ management portal and go the [catalog](https://portal.swisscomcloud.com/catalog/). From there you can order a new **Dynamic Data Center**. The *"Service Level"* doesn't matter for Kubernetes, pick anything you want.

See the official DCS+ documentation on [Dynamic Data Center](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#dynamic-data-center) for more information.

Configure the name of your newly created DDC in `terraform.tfvars -> vcd_vdc`.

##### Edge Gateway

Login to the DCS+ management portal and go the [My Items](https://portal.swisscomcloud.com/my-items/) view. From here click on the right hand side on *"Actions"* and then select **Create Internet Access** for your *Dynamic Data Center*. Make sure to check the box *"Edge Gateway"* and then fill out all the other values. For *"IP Range Size"* you can select the smallest value available, this Terraform module will only need one public IP for an external LoadBalancer. On *"Edge Gateway Configuration"* it is important that you select the **Large** configuration option to create an Edge Gateway with an advanced feature set, otherwise it will will be missing loadbalancing features and not function correctly!

See the official DCS+ documentation on [Create Internet Access](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#internet-access) for more information.

Configure the name of this Edge Gateway in `terraform.tfvars -> vcd_edgegateway`.

##### API User

Login to the DCS+ management portal and go the [catalog](https://portal.swisscomcloud.com/catalog/). From there you can order a new **vCloudDirector API User**. Make sure to leave *"Read only user?"* unchecked, otherwise your new API user will not be able to do anything!

See the official DCS+ documentation on [Cloud Director API Users](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#cloud-director-api-user) for more information.

Configure the new API username and password in `terraform.tfvars` at `vcd_api_username` and `vcd_api_password`.
Make sure you also set the API URL at `vcd_api_url`. Check out the official DCS+ documentation on how to determine the API URL value, see [Cloud Director API - API access methods](https://dcsguide.scapp.swisscom.com/ug3/vcloud_director.html#api-access-methods).

#### :warning: Download Ubuntu OS image

Before you can deploy a Kubernetes cluster you need to download the Ubuntu OS cloud-image that will be used for the virtual machines on DCS+.
It is recommended that you use the latest Ubuntu 22.04 LTS (Long Term Support) image from [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/jammy/current/). By default this Terraform module will be looking for a file named `ubuntu-22.04-server-cloudimg-amd64.ova` in the current working directory:
```bash
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.ova -O ubuntu-22.04-server-cloudimg-amd64.ova
```

> **Note**: Provisioning of the DCS+ infrastructure will fail if the image file is not present and cannot be uploaded!

### Configuration

#### Cluster sizing recommendations for your `terraform.tfvars`

Here are some examples for possible cluster sizes:

##### Small / Starter
| Node type | Setting | Variable name | Value |
| --- | --- | --- | --- |
| Control plane | Number of VMs | `k8s_control_plane_instances` | `1` |
| Control plane | vCPUs | `k8s_control_plane_cpus` | `1` |
| Control plane | Memory (in MB) | `k8s_control_plane_memory` | `2048` |
| Worker | Number of VMs | `k8s_worker_instances` | `1` |
| Worker | vCPUs | `k8s_worker_cpus` | `2` |
| Worker | Memory (in MB) | `k8s_worker_memory` | `4096` |
| Worker | Disk size (in MB) | `k8s_worker_disk_size` | `81920` |

##### Medium / Default values
| Node type | Setting | Variable name | Value |
| --- | --- | --- | --- |
| Control plane | Number of VMs | `k8s_control_plane_instances` | `3` |
| Control plane | vCPUs | `k8s_control_plane_cpus` | `2` |
| Control plane | Memory (in MB) | `k8s_control_plane_memory` | `2048` |
| Worker | Number of VMs | `k8s_worker_instances` | `3` |
| Worker | vCPUs | `k8s_worker_cpus` | `4` |
| Worker | Memory (in MB) | `k8s_worker_memory` | `8192` |
| Worker | Disk size (in MB) | `k8s_worker_disk_size` | `245760` |

##### Large
| Node type | Setting | Variable name | Value |
| --- | --- | --- | --- |
| Control plane | Number of VMs | `k8s_control_plane_instances` | `3` |
| Control plane | vCPUs | `k8s_control_plane_cpus` | `2` |
| Control plane | Memory (in MB) | `k8s_control_plane_memory` | `4096` |
| Worker | Number of VMs | `k8s_worker_instances` | `9` |
| Worker | vCPUs | `k8s_worker_cpus` | `4` |
| Worker | Memory (in MB) | `k8s_worker_memory` | `16384` |
| Worker | Disk size (in MB) | `k8s_worker_disk_size` | `163840` |

> **Note**: The more worker nodes you have, the smaller the disk size gets that they need in order to distribute and cover all your `PersistentVolume` needs. This is why the worker nodes in the *Large* cluster example actually have a smaller disk than in the *Medium* example.

Set the amount of control plane nodes to either be 1, 3 or 5. They have to be an odd number for the quorum to work correctly, and anything above 5 is not really that beneficial anymore. For a highly-available setup usually the perfect number of control plane nodes is `3`.

The amount of worker nodes can be set to anything between 1 and 100. Do not set it to a number higher than that, this Terraform module currently supports only a maximum of 100 worker nodes!

### Provisioning
![DCS+ Terraform](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_terraform.gif)

## Up and running

After the initial installation or upgrade via `terraform apply` has finished, you should see a couple of output parameters in your terminal:
```bash
Outputs:

cluster_info = "export KUBECONFIG=kubeconfig; kubectl cluster-info; kubectl get pods -A"
grafana_admin_password = "export KUBECONFIG=kubeconfig; kubectl -n grafana get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo"
grafana_url = "https://grafana.your-domain-name.com"
kubernetes_dashboard_token = "export KUBECONFIG=kubeconfig; kubectl -n kubernetes-dashboard create token kubernetes-dashboard"
kubernetes_dashboard_url = "https://dashboard.your-domain-name.com"
loadbalancer_ip = "147.5.206.133"
longhorn_dashboard = "export KUBECONFIG=kubeconfig; kubectl -n longhorn-system port-forward service/longhorn-frontend 9999:80"
```
These give you a starting point and some example commands you can run to access and use your newly provisioned Kubernetes cluster.

### kubectl

There should be a `kubeconfig` file written to the Terraform module working directory. This file contains the configuration and credentials to access and manage your Kubernetes cluster. You can set the environment variable `KUBECONFIG` to this file to have your `kubectl` CLI use it for the remainder of your terminal session.
```bash
export KUBECONFIG=$(pwd)/kubeconfig
```
Now you can run any `kubectl` commands you want to manage your cluster, for example:
```bash
$ kubectl cluster-info
Kubernetes control plane is running at https://147.5.206.133:6443
CoreDNS is running at https://147.5.206.133:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://147.5.206.133:6443/api/v1/namespaces/kube-system/services/https:metrics-server:https/proxy

$ kubectl get nodes -o wide
NAME           STATUS   ROLES                       AGE   VERSION        INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
k8s-server-0   Ready    control-plane,etcd,master   40h   v1.24.3+k3s1   10.0.80.50    <none>        Ubuntu 22.04.1 LTS   5.15.0-46-generic   containerd://1.6.6-k3s1
k8s-server-1   Ready    control-plane,etcd,master   40h   v1.24.3+k3s1   10.0.80.51    <none>        Ubuntu 22.04.1 LTS   5.15.0-46-generic   containerd://1.6.6-k3s1
k8s-server-2   Ready    control-plane,etcd,master   40h   v1.24.3+k3s1   10.0.80.52    <none>        Ubuntu 22.04.1 LTS   5.15.0-46-generic   containerd://1.6.6-k3s1
k8s-worker-0   Ready    <none>                      39h   v1.24.3+k3s1   10.0.80.100   <none>        Ubuntu 22.04.1 LTS   5.15.0-46-generic   containerd://1.6.6-k3s1
k8s-worker-1   Ready    <none>                      39h   v1.24.3+k3s1   10.0.80.101   <none>        Ubuntu 22.04.1 LTS   5.15.0-46-generic   containerd://1.6.6-k3s1
k8s-worker-2   Ready    <none>                      39h   v1.24.3+k3s1   10.0.80.102   <none>        Ubuntu 22.04.1 LTS   5.15.0-46-generic   containerd://1.6.6-k3s1

$ kubectl get namespaces
NAME                   STATUS   AGE
cert-manager           Active   39h
default                Active   40h
grafana                Active   37h
hairpin-proxy          Active   38h
ingress-nginx          Active   39h
kube-node-lease        Active   40h
kube-public            Active   40h
kube-system            Active   40h
kubernetes-dashboard   Active   39h
loki                   Active   36h
longhorn-system        Active   39h
prometheus             Active   37h
promtail               Active   36h
```

### DCS+
![DCS+ Dashboard](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_dashboard.png)

By default (unless configured otherwise in your `terraform.tfvars`) once the deployment is done you should see something similar to above in your DCS+ Portal. There will be 1 bastion host (a jumphost VM for SSH access to the other VMs), 3 control plane VMs for the Kubernetes server nodes, and 3 worker VMs that are responsible for running your Kubernetes workload.

### Kubernetes-Dashboard
![DCS+ Dashboard](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_k8s_dashboard.png)

The Kubernetes dashboard will automatically be available to you after installation under [https://dashboard.your-domain-name.com](https://grafana.your-domain-name.com) (with *your-domain-name.com* being the value you configured in `terraform.tfvars -> k8s_domain_name`)

In order to login you will first need to request a temporary access token from your Kubernetes cluster:
```bash
kubectl -n kubernetes-dashboard create token kubernetes-dashboard
```
With this token you will be able to sign in into the dashboard.
> **Note**: This token is only valid temporarily, you will need request a new one each time it has expired.

### Grafana
![DCS+ Grafana](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_grafana.png)

The Grafana dashboard will automatically be available to you after installation under [https://grafana.your-domain-name.com](https://grafana.your-domain-name.com) (with *your-domain-name.com* being the value you configured in `terraform.tfvars -> k8s_domain_name`)

The username for accessing Grafana will be `admin` and the password can be retrieved from Kubernetes by running:
```bash
kubectl -n grafana get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

### Longhorn
![DCS+ Grafana](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_k8s_longhorn.png)

To access the Longhorn dashboard you have to initialize a localhost port-forwarding towards the service on the cluster, since it is not exposed externally:
```bash
kubectl -n longhorn-system port-forward service/longhorn-frontend 9999:80
```
This will setup a port-forwarding for `localhost:9999` on your machine. Now you can open the Longhorn dashboard in your browser by going to [http://localhost:9999/#/dashboard](http://localhost:9999/).

# TODO:

This still needs to be done to finish this repo. The text here and below will be removed before its done and ready for `v1.0.0`.

- [ ] write proper, extensive documentation
  - [ ] overhaul README.md
  - [ ] Explain architecture picture, document decisions and setup
  - [ ] Requirements for DCS tenant: VDC, Edge Gateway with Internet
  - [ ] Installation instructions, full in-depth guide with screenshots
  - [ ] Configuration instructions, explain all tfvars / variables in detail
  - [ ] Module description, for each of the 3 submodules
  - [ ] Customization, explain possible customization options to users
  - [ ] Day 2 operations, component and cluster upgrades
