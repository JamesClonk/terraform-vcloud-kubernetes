terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.6.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "helm" {
  kubernetes {
    host                   = var.api_endpoint
    cluster_ca_certificate = var.cluster_ca_certificate
    client_certificate     = var.client_certificate
    client_key             = var.client_key
  }
}
# provider "kubernetes" {
#   host                   = var.api_endpoint
#   cluster_ca_certificate = var.cluster_ca_certificate
#   client_certificate     = var.client_certificate
#   client_key             = var.client_key
# }

resource "local_sensitive_file" "kubeconfig_file" {
  filename        = "k3s_kubeconfig"
  content         = var.kube_config
  file_permission = "0600"
}

output "cluster_endpoint" {
  value = var.api_endpoint
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

resource "helm_release" "ingress_nginx" {
  name       = "ingress-controller"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  set {
    name  = "controller.hostPort.enabled"
    value = "true"
  }
  set {
    name  = "controller.kind"
    value = "DaemonSet"
  }
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }
  set {
    name  = "controller.service.type"
    value = "ClusterIP"
  }
}
