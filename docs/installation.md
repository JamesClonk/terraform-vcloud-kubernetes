Table of Contents
=================
* [Installation](#installation)
  + [Requirements](#requirements)
    - [DCS+ resources](#dcs-resources)
      * [Dynamic Data Center](#dynamic-data-center)
      * [Edge Gateway](#edge-gateway)
      * [API User](#api-user)
    - [Download Ubuntu OS image](#download-ubuntu-os-image)
    - [Local CLI tools](#local-cli-tools)
  + [Configuration](#configuration)
    - [Domain name](#domain-name)
    - [Helm charts](#helm-charts)
    - [Cluster sizing recommendations](#cluster-sizing-recommendations)
      * [Small / Starter](#small--starter)
      * [Medium / Default values](#medium--default-values)
      * [Large](#large)
  + [Provisioning](#provisioning)

# Installation

## Requirements

To use this Terraform module you will need to have a valid account / contract number on [Swisscom DCS+](https://dcsguide.scapp.swisscom.com/).

Configure your contract number (PRO-number) in `terraform.tfvars -> vcd_org`.

### DCS+ resources

For deploying a Kubernetes cluster on DCS+ you will need to manually create the following resources first before you can proceed:
- a VCD / Dynamic Data Center (DDC)
- an Edge Gateway with Internet in your VCD/DDC
- an API User

#### Dynamic Data Center

Login to the DCS+ management portal and go to [Catalog](https://portal.swisscomcloud.com/catalog/). From there you can order a new **Dynamic Data Center**. The *"Service Level"* doesn't matter for Kubernetes, pick anything you want.

See the official DCS+ documentation on [Dynamic Data Center](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#dynamic-data-center) for more information.

Configure the name of your newly created DDC in `terraform.tfvars -> vcd_vdc`.

#### Edge Gateway

Login to the DCS+ management portal and go to [My Items](https://portal.swisscomcloud.com/my-items/) view. From here click on the right hand side on *"Actions"* and then select **Create Internet Access** for your *Dynamic Data Center*. Make sure to check the box *"Edge Gateway"* and then fill out all the other values. For *"IP Range Size"* you can select the smallest value available, this Terraform module will only need one public IP for an external LoadBalancer. On *"Edge Gateway Configuration"* it is important that you select the **Large** configuration option to create an Edge Gateway with an advanced feature set, otherwise it will will be missing loadbalancing features and not function correctly!

See the official DCS+ documentation on [Create Internet Access](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#internet-access) for more information.

Configure the name of this Edge Gateway in `terraform.tfvars -> vcd_edgegateway`.

> **Note**: Also have a look in the vCloud Director web UI and check what the external/public IP assigned to this newly created Edge Gateway is by going to its **Configuration -> Gateway Interfaces** page and looking for the **Primary IP**. You will need this IP to set up a DNS *A* and a *CNAME* record with it.

#### API User

Login to the DCS+ management portal and go to [Catalog](https://portal.swisscomcloud.com/catalog/). From there you can order a new **vCloudDirector API User**. Make sure to leave *"Read only user?"* unchecked, otherwise your new API user will not be able to do anything!

See the official DCS+ documentation on [Cloud Director API Users](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#cloud-director-api-user) for more information.

Configure the new API username and password in `terraform.tfvars` at `vcd_api_username` and `vcd_api_password`.
Make sure you also set the API URL at `vcd_api_url`. Check out the official DCS+ documentation on how to determine the API URL value, see [Cloud Director API - API access methods](https://dcsguide.scapp.swisscom.com/ug3/vcloud_director.html#api-access-methods).

### Download Ubuntu OS image

:warning: Before you can deploy a Kubernetes cluster you need to download the Ubuntu OS cloud-image that will be used for the virtual machines on DCS+.
It is recommended that you use the latest Ubuntu 22.04 LTS (Long Term Support) image from [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/jammy/current/). By default this Terraform module will be looking for a file named `ubuntu-22.04-server-cloudimg-amd64.ova` in the current working directory:
```bash
$ wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.ova -O ubuntu-22.04-server-cloudimg-amd64.ova
```

> **Note**: Provisioning of the DCS+ infrastructure will fail if the image file is not present and cannot be uploaded!

### Local CLI tools

For deploying this Terraform module you will need to have all the following CLI tools installed on your machine:
- [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [git](https://git-scm.com/)

This module has so far only been tested running under Linux and MacOSX. Your experience with Windows tooling may vary.

## Configuration

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

### Domain name

The variable `k8s_domain_name` plays an important role in setting up your Kubernetes cluster. Many of the components that are installed will have [Ingresses](https://kubernetes.io/docs/concepts/services-networking/ingress/) created and configured with that domain name as part of their hostname. For example Grafana will be made available on `https://grafana.<k8s_domain_name>`.

In order for this to work correctly you should setup a new DNS **A** record for the domain name you want to be using, pointing it to the external/public IP of the Edge Gateway. Look for the IP in the vCloud Director web UI. After that you will also have to add a wildcard **CNAME** record, pointing to the newly created *A* record.

For example, if you want to use `my-kubernetes.my-domain.com`, the DNS entries would look something like this:
```bash
;ANSWER
*.my-kubernetes.my-domain.com. 600 IN CNAME my-kubernetes.my-domain.com.
my-kubernetes.my-domain.com. 600 IN A 147.5.206.13
```

> **Note**: If you do not set `k8s_domain_name`, or set it to an empty value, then the Terraform module will fallback to using `<loadbalancer_IP>.nip.io`. This should work for basic Ingress access, but might cause issues for automatic Let's Encrypt certificates!

### Helm charts

Apart from just provisioning a Kubernetes cluster on DCS+, this Terraform module will also install a set of commonly used components on top of your Kubernetes cluster. (See section "[Components on cluster](#components-on-cluster)" above for details)

The variable `k8s_enable_monitoring` allows you to enable or disable the installation of `Prometheus` and `Grafana` on your cluster. Set if to `false` if you do not want these components preinstalled.

The variable `k8s_enable_logging` allows you to enable or disable the installation of `Loki` and `Promtail` on your cluster. Set if to `false` if you do not want these components preinstalled.

The variable `k8s_enable_automatic_node_reboot` allows you to enable or disable the installation of `Kured` on your cluster. Set if to `false` if you do not want it to be installed and doing automatic Kubernetes node reboots.

Additionally the **Helm charts** section in `variables.tf` also specifies what versions are used for each of the Helm chart installations, and also for [K3s](https://k3s.io/) (Kubernetes) itself. Add these variables to your `terraform.tfvars` if you want to override any of them, but please be aware that versions other than the ones preconfigured in `variables.tf` are untested and thus not supported.

### Cluster sizing recommendations

There are also separate configuration variables for each aspect of the virtual machines that will be provisioned by this Terraform module. Have a look at the **Kubernetes resources** section in `variables.tf` if you want to have more control over the size and resources of your Kubernetes cluster.

Here are some examples for possible cluster size customizations:

#### Small / Starter
| Node type | Setting | Variable name | Value |
| --- | --- | --- | --- |
| Control plane | Number of VMs | `k8s_control_plane_instances` | `1` |
| Control plane | vCPUs | `k8s_control_plane_cpus` | `1` |
| Control plane | Memory (in MB) | `k8s_control_plane_memory` | `2048` |
| Worker | Number of VMs | `k8s_worker_instances` | `1` |
| Worker | vCPUs | `k8s_worker_cpus` | `2` |
| Worker | Memory (in MB) | `k8s_worker_memory` | `4096` |
| Worker | Disk size (in MB) | `k8s_worker_disk_size` | `81920` |

#### Medium / Default values
| Node type | Setting | Variable name | Value |
| --- | --- | --- | --- |
| Control plane | Number of VMs | `k8s_control_plane_instances` | `3` |
| Control plane | vCPUs | `k8s_control_plane_cpus` | `2` |
| Control plane | Memory (in MB) | `k8s_control_plane_memory` | `2048` |
| Worker | Number of VMs | `k8s_worker_instances` | `3` |
| Worker | vCPUs | `k8s_worker_cpus` | `4` |
| Worker | Memory (in MB) | `k8s_worker_memory` | `8192` |
| Worker | Disk size (in MB) | `k8s_worker_disk_size` | `245760` |

#### Large
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

> **Note**: Be aware that if you use less than 3 workers you should also decrease the default replica count of Longhorn volumes, either in the Longhorn global settings or for each volume itself. Otherwise they will be in a degraded state (since Longhorn can't provide the requested amount of replicas with less worker nodes) and might not work at all!

## Provisioning

Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) on your machine if you do not have it already. See the section about [local CLI tools](#local-cli-tools) above for all required tools needed.

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
