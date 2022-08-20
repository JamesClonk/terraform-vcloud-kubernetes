terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.5.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.1.0"
    }
  }
  required_version = ">= 1.2.0"
}

module "infrastructure" {
  source = "./infrastructure"

  vcd_api_url         = var.vcd_api_url
  vcd_api_username    = var.vcd_api_username
  vcd_api_password    = var.vcd_api_password
  vcd_token           = var.vcd_token
  vcd_org             = var.vcd_org
  vcd_vdc             = var.vcd_vdc
  vcd_auth_type       = var.vcd_auth_type
  vcd_logging_enabled = var.vcd_logging_enabled
  vcd_catalog         = var.vcd_catalog
  vcd_template        = var.vcd_template
  vcd_edgegateway     = var.vcd_edgegateway

  k8s_cidr                    = var.k8s_cidr
  k8s_cluster_name            = var.k8s_cluster_name
  k8s_ssh_public_key          = var.k8s_ssh_public_key
  k8s_bastion_memory          = var.k8s_bastion_memory
  k8s_bastion_cpus            = var.k8s_bastion_cpus
  k8s_control_plane_instances = var.k8s_control_plane_instances
  k8s_control_plane_memory    = var.k8s_control_plane_memory
  k8s_control_plane_cpus      = var.k8s_control_plane_cpus
  k8s_worker_instances        = var.k8s_worker_instances
  k8s_worker_memory           = var.k8s_worker_memory
  k8s_worker_cpus             = var.k8s_worker_cpus
  k8s_worker_disk_size        = var.k8s_worker_disk_size
}

module "kubernetes" {
  source = "./kubernetes"

  k8s_cidr         = var.k8s_cidr
  k8s_cluster_name = var.k8s_cluster_name

  k8s_ssh_private_key        = var.k8s_ssh_private_key
  k8s_bastion_username       = "kubernetes"
  k8s_control_plane_username = "kubernetes"
  k8s_worker_username        = "kubernetes"

  loadbalancer_ip = module.infrastructure.edge_gateway_external_ip
  domain_name     = var.k8s_domain_name

  k8s_bastion_ip              = module.infrastructure.edge_gateway_external_ip
  k8s_control_plane_instances = var.k8s_control_plane_instances
  k8s_worker_instances        = var.k8s_worker_instances

  k3s_version = var.k8s_k3s_version

  depends_on = [
    module.infrastructure.k8s_control_plane,
    module.infrastructure.k8s_worker
  ]
}

# resource "time_sleep" "wait_after_kubernetes" {
#   depends_on      = [module.kubernetes.kubernetes_ready]
#   create_duration = "60s"
# }

module "deployments" {
  source = "./deployments"

  loadbalancer_ip = module.infrastructure.edge_gateway_external_ip
  domain_name     = var.k8s_domain_name
  # cluster_api_endpoint   = replace(module.kubernetes.cluster_api_endpoint, cidrhost(var.k8s_cidr, 50), module.infrastructure.edge_gateway_external_ip)
  cluster_api_endpoint   = "https://${module.infrastructure.edge_gateway_external_ip}:6443"
  cluster_ca_certificate = module.kubernetes.cluster_ca_certificate
  client_certificate     = module.kubernetes.client_certificate
  client_key             = module.kubernetes.client_key

  helm_longhorn_version             = var.k8s_helm_longhorn_version
  helm_ingress_nginx_version        = var.k8s_helm_ingress_nginx_version
  helm_cert_manager_version         = var.k8s_helm_cert_manager_version
  helm_kubernetes_dashboard_version = var.k8s_helm_kubernetes_dashboard_version

  #depends_on = [time_sleep.wait_after_kubernetes]
}
