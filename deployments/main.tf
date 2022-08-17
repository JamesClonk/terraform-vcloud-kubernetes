terraform {
  required_providers {
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
  }
  required_version = ">= 1.2.0"
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_api_endpoint
    cluster_ca_certificate = var.cluster_ca_certificate
    client_certificate     = var.client_certificate
    client_key             = var.client_key
  }
}

provider "kubernetes" {
  host                   = var.cluster_api_endpoint
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
}

provider "kubectl" {
  host                   = var.cluster_api_endpoint
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
  apply_retry_count      = 5
}

# Longhorn is required to be installed, otherwise there would be no storage class for PVs/PVCs present on your cluster.
resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = var.helm_longhorn_version
  namespace        = "longhorn-system"
  create_namespace = "true"
}

# Strictly speaking anything below here is entirely optional and not required for a functioning cluster, but it is highly recommended to have an ingress-controller like ingress-nginx and cert-manager for TLS management installed nonetheless.
resource "helm_release" "ingress_nginx" {
  name             = "ingress-controller"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.helm_ingress_nginx_version
  namespace        = "ingress-nginx"
  create_namespace = "true"

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }
  set {
    name  = "controller.service.type"
    value = "NodePort"
  }
  set {
    name  = "controller.service.nodePorts.http"
    value = "30080"
  }
  set {
    name  = "controller.service.nodePorts.https"
    value = "30443"
  }
}

data "kubectl_path_documents" "hairpin_proxy" {
  pattern = "${path.module}/external/hairpin-proxy-0.2.1.yaml"
}

resource "kubectl_manifest" "hairpin_proxy" {
  for_each   = toset(data.kubectl_path_documents.hairpin_proxy.documents)
  yaml_body  = each.value
  apply_only = true
  depends_on = [helm_release.ingress_nginx]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.helm_cert_manager_version
  namespace        = "cert-manager"
  create_namespace = "true"

  set {
    name  = "installCRDs"
    value = "true"
  }

  # values = [
  #   <<-EOT
  #   podDnsPolicy: "None"
  #   podDnsConfig:
  #     nameservers:
  #     - 1.1.1.1
  #     - 8.8.8.8
  #   EOT
  # ]

  depends_on = [
    helm_release.ingress_nginx,
    kubectl_manifest.hairpin_proxy
  ]
}

resource "kubectl_manifest" "cluster_issuer" {
  yaml_body  = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: lets-encrypt
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: lets-encrypt
        solvers:
        - http01:
            ingress:
              class: nginx
    YAML
  apply_only = true
  depends_on = [helm_release.cert_manager]
}

resource "helm_release" "kubernetes_dashboard" {
  name             = "kubernetes-dashboard"
  repository       = "https://kubernetes.github.io/dashboard/"
  chart            = "kubernetes-dashboard"
  version          = var.helm_kubernetes_dashboard_version
  namespace        = "kubernetes-dashboard"
  create_namespace = "true"

  set {
    name  = "metricsScraper.enabled"
    value = "true"
  }
  set {
    name  = "ingress.enabled"
    value = "true"
  }
  set {
    name  = "ingress.className"
    value = "nginx"
  }

  values = [
    <<-EOT
    ingress:
      hosts:
      - dashboard.${var.domain_name != "" ? var.domain_name : "${var.loadbalancer_ip}.nip.io"}
      tls:
      - secretName: kubernetes-dashboard-tls
        hosts:
        - dashboard.${var.domain_name != "" ? var.domain_name : "${var.loadbalancer_ip}.nip.io"}
      annotations:
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
        nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
        cert-manager.io/cluster-issuer: "lets-encrypt"
    EOT
  ]

  depends_on = [
    kubectl_manifest.cluster_issuer,
    kubectl_manifest.hairpin_proxy,
    helm_release.ingress_nginx,
    helm_release.cert_manager,
  ]
}

resource "kubernetes_manifest" "kubernetes_dashboard_cluster_role_binding" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "kubernetes-dashboard"
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "cluster-admin"
    }
    subjects = [{
      kind      = "ServiceAccount"
      name      = "kubernetes-dashboard"
      namespace = "kubernetes-dashboard"
    }]
  }
  depends_on = [helm_release.kubernetes_dashboard]
}
