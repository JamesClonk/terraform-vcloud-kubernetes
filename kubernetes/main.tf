terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.1.0"
    }
  }
  required_version = ">= 1.2.0"
}

module "k3s" {
  source  = "xunleii/k3s/module"
  version = "v3.1.0"

  k3s_version    = var.k3s_version
  drain_timeout  = "600s"
  managed_fields = ["label", "taint"]

  servers = {
    for i in range(var.k8s_control_plane_instances) :
    "k8s-server-${i}" => {
      ip = cidrhost(var.k8s_cidr, 50 + i)
      connection = {
        user             = "root"
        password         = var.k8s_control_plane_root_password
        bastion_host     = var.k8s_bastion_ip
        bastion_port     = var.k8s_bastion_port
        bastion_user     = "root"
        bastion_password = var.k8s_bastion_root_password
      }
      flags = [
        "--disable traefik",
        "--tls-san ${var.loadbalancer_ip}",
        "--tls-san ${var.domain_name != "" ? var.domain_name : "${var.loadbalancer_ip}.nip.io"}"
      ]
      labels      = { "node.kubernetes.io/type" = "master" }
      annotations = { "server.index" : i }
    }
  }

  agents = {
    for i in range(var.k8s_worker_instances) :
    "k8s-worker-${i}" => {
      ip = cidrhost(var.k8s_cidr, 100 + i)
      connection = {
        user             = "root"
        password         = var.k8s_worker_root_password
        bastion_host     = var.k8s_bastion_ip
        bastion_port     = var.k8s_bastion_port
        bastion_user     = "root"
        bastion_password = var.k8s_bastion_root_password
      }
      labels      = { "node.kubernetes.io/pool" = "worker" }
      annotations = { "worker.index" : i }
    }
  }
}
