# terraform-vcloud-kubernetes
Deploy Kubernetes on vCloud / [Swisscom DCS+](https://dcsguide.scapp.swisscom.com/)

## Kubernetes cluster with k3s

### Architecture
![DCS+ Kubernetes Architecture](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_k8s.png)

### Provisioning
![DCS+ Terraform](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_terraform.gif)

### Up and running

##### DCS+
![DCS+ Dashboard](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_dashboard.png)
##### Kubernetes-Dashboard
![DCS+ Dashboard](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_k8s_dashboard.png)
##### Grafana
![DCS+ Grafana](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_grafana.png)
##### Longhorn
![DCS+ Grafana](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_k8s_longhorn.png)

# TODO:

This still needs to be done to finish this repo. The text here and below will be removed before its done and ready for `v1.0.0`.

- [x] add this TODO list 😂
- [x] change SSH procedure from root/pw to ssh-keys
  - [x] add ssh-keys to variables / tfvars, remove root passwords
  - [x] change VM/node setup in `infrastructure` module on vcloud
  - [x] change VM/node access for K3s setup in `kubernetes` module
- [ ] write proper, extensive documentation
  - [ ] overhaul README.md
  - [ ] add all documentation it into a /docs subdir, as per tf convention
  - [ ] Explain architecture picture, document decisions and setup
  - [ ] Requirements for DCS tenant: VDC, Edge Gateway with Internet
  - [ ] Installation instructions, full in-depth guide with screenshots
  - [ ] Configuration instructions, explain all tfvars / variables in detail
  - [ ] Module description, for each of the 3 submodules
  - [ ] Customization, explain possible customization options to users
  - [ ] Day 2 operations, component and cluster upgrades
  - [ ] Document access to components, Grafana and Kubernetes-Dashboard specifically, with screenshots
  - [ ] Document user token creation for Kubernetes-Dashboard access
- [x] add Prometheus to `deployments` module
  - [x] make it optional via boolean flag and `count = var.flag ? 1 : 0` in resource, to be disabled by default?
- [ ] add Loki to `deployments` module
  - [ ] make it optional via boolean flag and `count = var.flag ? 1 : 0` in resource, to be disabled by default?
- [x] add Grafana to `deployments` module
  - [x] customize Grafana with local admin user, to be provided via variables / tfvars
  - [x] Add ingress to Grafana for access
  - [x] Output Grafana Ingress URL at the end for the user
  - [x] make it optional via boolean flag and `count = var.flag ? 1 : 0` in resource, to be disabled by default?
- [x] Output Kubernetes-Dashboard Ingress URL at the end for the user
- [x] Add Helm chart and component versions to variables / tfvars
- [x] Make sure loadbalancer rules cover everything
  - [x] k8s-api for cp, http and https ports for workers, entire nodeport range for workers
  - [x] should bastion host SSH stay via DNAT or also be ported onto the loadbalancer?

#### Maybe in the future?
- [ ] Replace standalone K3s control plane with Rancher module control plane
  - [ ] Deploy Rancher control plane after Bastion host
  - [ ] Deploy "workload" cluster (with its own cp) through Rancher tf module

To consider: A standalone Rancher control plane just for one single workload cluster might be overkill? 🤔
