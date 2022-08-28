# terraform-dcs-kubernetes

[![Build](https://img.shields.io/github/workflow/status/swisscom/terraform-dcs-kubernetes/Update?label=Build)](https://github.com/swisscom/terraform-dcs-kubernetes/actions/workflows/update.yml)
[![License](https://img.shields.io/badge/License-Apache--2.0-lightgrey)](https://github.com/swisscom/terraform-dcs-kubernetes/blob/master/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Kubernetes-blue)](https://kubernetes.io/)
[![IaC](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)

Deploy a Kubernetes cluster on [Swisscom DCS+](https://dcsguide.scapp.swisscom.com/)

-----

Table of Contents
=================
* [Kubernetes cluster with k3s](#kubernetes-cluster-with-k3s)
  + [Architecture](#architecture)
  + [Components on cluster](#components-on-cluster)
* [Installation](#installation)
  + [Requirements](#requirements)
    - [DCS+ resources](#dcs-resources)
      * [Dynamic Data Center](#dynamic-data-center)
      * [Edge Gateway](#edge-gateway)
      * [API User](#api-user)
    - [Download Ubuntu OS image](#download-ubuntu-os-image)
  + [Configuration](#configuration)
    - [Domain name](#domain-name)
    - [Helm charts](#helm-charts)
    - [Cluster sizing recommendations](#cluster-sizing-recommendations)
      * [Small / Starter](#small--starter)
      * [Medium / Default values](#medium--default-values)
      * [Large](#large)
  + [Provisioning](#provisioning)
* [Up and running](#up-and-running)
  + [kubectl](#kubectl)
  + [DCS+](#dcs)
  + [Kubernetes-Dashboard](#kubernetes-dashboard)
  + [Grafana](#grafana)
  + [Longhorn](#longhorn)

## Kubernetes cluster with k3s

This Terraform module supports you in creating a Kubernetes cluster with [K3s](https://k3s.io/) on [Swisscom DCS+](https://www.swisscom.ch/en/business/enterprise/offer/cloud/cloudservices/dynamic-computing-services.html) infrastructure. It also installs and manages additional deployments on the cluster, such as ingress-nginx, cert-manager, longhorn, and a whole set of logging/metrics/monitoring related components.
It consists of three different submodules, [infrastructure](/infrastructure/), [kubernetes](/kubernetes/) and [deployments](/deployments/). Each of these is responsible for a specific subset of features provided by the overall Terraform module.

The **infrastructure** module will provision resources on DCS+ and setup a private internal network (10.0.80.0/24 CIDR by default), attach an Edge Gateway with an external public IP and configure loadbalancing services, deploy a bastion host (jumphost) for external SSH access into the private network, and finally a set of Kubernetes control plane and worker nodes for hosting your workload.

The **kubernetes** module will then connect via SSH over the bastion host to all those control plane and worker nodes and install a K3s Kubernetes cluster on them.

Finally the **deployments** module is responsible for installing system components and software on to the Kubernetes cluster. It does most of its work through the official Helm charts of each component, plus some additional customization directly via kubectl / manifests.

The final result is a fully functioning, highly available Kubernetes cluster, complete with all the batteries included you need to get you started. *Ingress* Controller for HTTP virtual hosting / routing, TLS certificate management with automatic Let's Encrypt certificates for all your HTTPS traffic, *PersistVolume* and storage management with optional backups, and an entire monitoring stack for metrics and logs.

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

For deploying a Kubernetes cluster on DCS+ you will need to manually create the following resources first before you can proceed:
- a VCD / Dynamic Data Center (DDC)
- an Edge Gateway with Internet in your VCD/DDC
- an API User

##### Dynamic Data Center

Login to the DCS+ management portal and go to [Catalog](https://portal.swisscomcloud.com/catalog/). From there you can order a new **Dynamic Data Center**. The *"Service Level"* doesn't matter for Kubernetes, pick anything you want.

See the official DCS+ documentation on [Dynamic Data Center](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#dynamic-data-center) for more information.

Configure the name of your newly created DDC in `terraform.tfvars -> vcd_vdc`.

##### Edge Gateway

Login to the DCS+ management portal and go to [My Items](https://portal.swisscomcloud.com/my-items/) view. From here click on the right hand side on *"Actions"* and then select **Create Internet Access** for your *Dynamic Data Center*. Make sure to check the box *"Edge Gateway"* and then fill out all the other values. For *"IP Range Size"* you can select the smallest value available, this Terraform module will only need one public IP for an external LoadBalancer. On *"Edge Gateway Configuration"* it is important that you select the **Large** configuration option to create an Edge Gateway with an advanced feature set, otherwise it will will be missing loadbalancing features and not function correctly!

See the official DCS+ documentation on [Create Internet Access](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#internet-access) for more information.

Configure the name of this Edge Gateway in `terraform.tfvars -> vcd_edgegateway`.

> **Note**: Also have a look in the vCloud Director web UI and check what the external/public IP assigned to this newly created Edge Gateway is. You need the IP to set up a DNS *A* and a *CNAME* record with it.

##### API User

Login to the DCS+ management portal and go to [Catalog](https://portal.swisscomcloud.com/catalog/). From there you can order a new **vCloudDirector API User**. Make sure to leave *"Read only user?"* unchecked, otherwise your new API user will not be able to do anything!

See the official DCS+ documentation on [Cloud Director API Users](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#cloud-director-api-user) for more information.

Configure the new API username and password in `terraform.tfvars` at `vcd_api_username` and `vcd_api_password`.
Make sure you also set the API URL at `vcd_api_url`. Check out the official DCS+ documentation on how to determine the API URL value, see [Cloud Director API - API access methods](https://dcsguide.scapp.swisscom.com/ug3/vcloud_director.html#api-access-methods).

#### Download Ubuntu OS image

:warning: Before you can deploy a Kubernetes cluster you need to download the Ubuntu OS cloud-image that will be used for the virtual machines on DCS+.
It is recommended that you use the latest Ubuntu 22.04 LTS (Long Term Support) image from [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/jammy/current/). By default this Terraform module will be looking for a file named `ubuntu-22.04-server-cloudimg-amd64.ova` in the current working directory:
```bash
$ wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.ova -O ubuntu-22.04-server-cloudimg-amd64.ova
```

> **Note**: Provisioning of the DCS+ infrastructure will fail if the image file is not present and cannot be uploaded!

### Configuration

All possible configuration variables are specified in the [variables.tf](/variables.tf) file in this repository. Most of them already have a sensible default value and only a small handful are required to be configured manually. For any such variable that does not have a default (or you want to set to a different value) you will have to create and add a configuration entry in your `terraform.tfvars` file.

To get you started quickly there is also an example configuration file included, [terraform.example.tfvars](/terraform.example.tfvars), which contains the minimal set of variables required to use this Terraform module.

```terraform
vcd_api_url      = "https://vcd-pod-bravo.swisscomcloud.com/api"
vcd_api_username = "api_vcd_my_username"
vcd_api_password = "my_password"

vcd_org         = "PRO-0123456789"
vcd_vdc         = "my-data-center"
vcd_edgegateway = "PRO-0123456789-my-gateway"

k8s_domain_name     = "my-kubernetes.my-domain.com"
k8s_ssh_public_key  = "ssh-rsa AAAAB3..."
k8s_ssh_private_key = <<EOT
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
EOT
```

You can just copy this file over to `terraform.tfvars` and start editing it to fill in your values:
```bash
$ cp terraform.example.tfvars terraform.tfvars
$ vim terraform.tfvars
```

#### Domain name

The variable `k8s_domain_name` plays an important role in setting up your Kubernetes cluster. Many of the components that are installed will have [Ingresses](https://kubernetes.io/docs/concepts/services-networking/ingress/) created and configured with that domain name as part of their hostname. For example Grafana will be made available on `https://grafana.<k8s_domain_name>`.

In order for this to work correctly you should setup a new DNS **A** record for the domain name you want to be using, pointing it to the external/public IP of the Edge Gateway. Look for the IP in the vCloud Director web UI. After that you will also have to add a wildcard **CNAME** record, pointing to the newly created *A* record.

For example, if you want to use `my-kubernetes.my-domain.com`, the DNS entries would look something like this:
```bash
;ANSWER
*.my-kubernetes.my-domain.com. 600 IN CNAME my-kubernetes.my-domain.com.
my-kubernetes.my-domain.com. 600 IN A 147.5.206.13
```

> **Note**: If you do not set `k8s_domain_name`, or set it to an empty value, then the Terraform module will fallback to using `<loadbalancer_IP>.nip.io`. This should work for basic Ingress access, but might cause issues for automatic Let's Encrypt certificates!

#### Helm charts

Apart from just provisioning a Kubernetes cluster on DCS+, this Terraform module will also install a set of commonly used components on top of your Kubernetes cluster. (See section "[Components on cluster](#components-on-cluster)" above for details)

The variable `k8s_enable_monitoring` allows you to enable or disable the installation of `Prometheus` and `Grafana` on your cluster. Set if to `false` if you do not want these components preinstalled.

The variable `k8s_enable_logging` allows you to enable or disable the installation of `Loki` and `Promtail` on your cluster. Set if to `false` if you do not want these components preinstalled.

Additionally the **Helm charts** section in `variables.tf` also specifies what versions are used for each of the Helm chart installations, and also for [K3s](https://k3s.io/) (Kubernetes) itself. Add these variables to your `terraform.tfvars` if you want to override any of them, but please be aware that versions other than the ones preconfigured in `variables.tf` are untested and thus not supported.

#### Cluster sizing recommendations

There are also separate configuration variables for each aspect of the virtual machines that will be provisioned by this Terraform module. Have a look at the **Kubernetes resources** section in `variables.tf` if you want to have more control over the size and resources of your Kubernetes cluster.

Here are some examples for possible cluster size customizations:

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

Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) on your machine if you do not have it already.

After you have configured `terraform.tfstate`, the first step you have to do is initialize this Terraform module and install all its dependencies:
```bash
$ terraform init
```

Before you provision the new Kubernetes cluster you can do a "dry-run" and check what Terraform would do:
```bash
$ terraform plan
```
If this is your first run of `terraform plan` this will likely show you a huge list of changes and missing resources. Everything shown here is what Terraform will create for you in order to provision a Kubernetes cluster on DCS+.

Finally once everything is ready and you are satisfied with the `plan` output, you can then run `terraform apply` to actually create the Kubernetes cluster:
```bash
$ terraform apply
```
It will once more display the difference between current and target state, and ask you to confirm if you want to proceed. Type `yes` and hit Enter to continue.

The first run of `terraform apply` is likely going to take quite a bit of time to finish, up to 20 minutes, as it needs to create a lot of new resources on DCS+. Just let it run until it finishes.

## Up and running

After the initial installation or upgrade with `terraform apply` has finished, you should see a couple of output parameters in your terminal:
```bash
Outputs:

cluster_info = "export KUBECONFIG=kubeconfig; kubectl cluster-info; kubectl get pods -A"
grafana_admin_password = "export KUBECONFIG=kubeconfig; kubectl -n grafana get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo"
grafana_url = "https://grafana.my-kubernetes.my-domain.com"
kubernetes_dashboard_token = "export KUBECONFIG=kubeconfig; kubectl -n kubernetes-dashboard create token kubernetes-dashboard"
kubernetes_dashboard_url = "https://dashboard.my-kubernetes.my-domain.com"
loadbalancer_ip = "147.5.206.133"
longhorn_dashboard = "export KUBECONFIG=kubeconfig; kubectl -n longhorn-system port-forward service/longhorn-frontend 9999:80"
```
These give you a starting point and some example commands you can run to access and use your newly provisioned Kubernetes cluster.

### kubectl

There should be a `kubeconfig` file written to the Terraform module working directory. This file contains the configuration and credentials to access and manage your Kubernetes cluster. You can set the environment variable `KUBECONFIG` to this file to have your `kubectl` CLI use it for the remainder of your terminal session.
```bash
$ export KUBECONFIG=$(pwd)/kubeconfig
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

The Kubernetes dashboard will automatically be available to you after installation under [https://dashboard.my-kubernetes.my-domain.com](https://grafana.my-kubernetes.my-domain.com) (with *my-kubernetes.my-domain.com* being the value you configured in `terraform.tfvars -> k8s_domain_name`)

In order to login you will first need to request a temporary access token from your Kubernetes cluster:
```bash
$ kubectl -n kubernetes-dashboard create token kubernetes-dashboard
```
With this token you will be able to sign in into the dashboard.
> **Note**: This token is only valid temporarily, you will need request a new one each time it has expired.

### Grafana
![DCS+ Grafana](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_grafana.png)

The Grafana dashboard will automatically be available to you after installation under [https://grafana.my-kubernetes.my-domain.com](https://grafana.my-kubernetes.my-domain.com) (with *my-kubernetes.my-domain.com* being the value you configured in `terraform.tfvars -> k8s_domain_name`)

The username for accessing Grafana will be `admin` and the password can be retrieved from Kubernetes by running:
```bash
$ kubectl -n grafana get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

### Longhorn
![DCS+ Grafana](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_k8s_longhorn.png)

To access the Longhorn dashboard you have to initialize a localhost port-forwarding towards the service on the cluster, since it is not exposed externally:
```bash
$ kubectl -n longhorn-system port-forward service/longhorn-frontend 9999:80
```
This will setup a port-forwarding for `localhost:9999` on your machine. Now you can open the Longhorn dashboard in your browser by going to [http://localhost:9999/#/dashboard](http://localhost:9999/).
