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

  k8s_cidr                        = var.k8s_cidr
  k8s_cluster_name                = var.k8s_cluster_name
  k8s_bastion_root_password       = var.k8s_bastion_root_password
  k8s_bastion_memory              = var.k8s_bastion_memory
  k8s_bastion_cpus                = var.k8s_bastion_cpus
  k8s_control_plane_root_password = var.k8s_control_plane_root_password
  k8s_control_plane_instances     = var.k8s_control_plane_instances
  k8s_control_plane_memory        = var.k8s_control_plane_memory
  k8s_control_plane_cpus          = var.k8s_control_plane_cpus
  k8s_worker_root_password        = var.k8s_worker_root_password
  k8s_worker_instances            = var.k8s_worker_instances
  k8s_worker_memory               = var.k8s_worker_memory
  k8s_worker_cpus                 = var.k8s_worker_cpus
}

module "kubernetes" {
  source = "./kubernetes"

  k8s_cidr                        = var.k8s_cidr
  k8s_cluster_name                = var.k8s_cluster_name
  k8s_bastion_root_password       = var.k8s_bastion_root_password
  k8s_control_plane_root_password = var.k8s_control_plane_root_password
  k8s_worker_root_password        = var.k8s_worker_root_password

  k8s_bastion_ip              = module.infrastructure.edge_gateway_external_ip
  k8s_control_plane_instances = var.k8s_control_plane_instances
  k8s_worker_instances        = var.k8s_worker_instances

  depends_on = [
    module.infrastructure.k8s_control_plane,
    module.infrastructure.k8s_worker
  ]
}

module "deployments" {
  source = "./deployments"

  cluster_api_endpoint   = replace(module.kubernetes.cluster_api_endpoint, cidrhost(var.k8s_cidr, 50), module.infrastructure.edge_gateway_external_ip)
  cluster_ca_certificate = module.kubernetes.cluster_ca_certificate
  client_certificate     = module.kubernetes.client_certificate
  client_key             = module.kubernetes.client_key
}

resource "local_sensitive_file" "kubeconfig_file" {
  filename        = "k3s_kubeconfig"
  content         = replace(module.kubernetes.kubeconfig, cidrhost(var.k8s_cidr, 50), module.infrastructure.edge_gateway_external_ip)
  file_permission = "0600"
}
output "kubeconfig" {
  value = local_sensitive_file.kubeconfig_file.filename
}
output "cluster_info" {
  value = format(
    "export KUBECONFIG=%s; kubectl cluster-info; kubectl get pods -A",
    local_sensitive_file.kubeconfig_file.filename,
  )
}
