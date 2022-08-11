resource "local_sensitive_file" "kubeconfig_file" {
  filename        = "k3s_kubeconfig"
  content         = module.k3s.kube_config
  file_permission = "0600"
}

output "cluster_endpoint" {
  value = module.k3s.kubernetes.api_endpoint
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

# provider "kubernetes" {
#   host                   = module.k3s.kubernetes.api_endpoint
#   cluster_ca_certificate = module.k3s.kubernetes.cluster_ca_certificate
#   client_certificate     = module.k3s.kubernetes.client_certificate
#   client_key             = module.k3s.kubernetes.client_key
# }

provider "helm" {
  kubernetes {
    host                   = module.k3s.kubernetes.api_endpoint
    cluster_ca_certificate = module.k3s.kubernetes.cluster_ca_certificate
    client_certificate     = module.k3s.kubernetes.client_certificate
    client_key             = module.k3s.kubernetes.client_key
  }
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
