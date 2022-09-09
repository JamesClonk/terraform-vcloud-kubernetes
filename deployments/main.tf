terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

resource "time_sleep" "wait_for_kubernetes" {
  create_duration = "30s"

  depends_on = [
    var.kubernetes_ready,
    var.cilium_ready
  ]
}

# Longhorn is required to be installed, otherwise there would be no storage class for PVs/PVCs present on your cluster.
resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = var.helm_longhorn_version
  namespace        = "longhorn-system"
  create_namespace = "true"

  depends_on = [time_sleep.wait_for_kubernetes]
}

# ======================================================================================================================
# Strictly speaking everything below here is entirely optional and not required for a functioning cluster, but it is highly recommended to have an ingress-controller like ingress-nginx and cert-manager for TLS management installed nonetheless.
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
  values = [
    <<-EOT
    controller:
      service:
        externalIPs:
        - ${var.loadbalancer_ip}
    EOT
  ]

  depends_on = [time_sleep.wait_for_kubernetes]
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

  depends_on = [helm_release.ingress_nginx]
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
  set {
    name  = "protocolHttp"
    value = "true"
  }
  set {
    name  = "service.externalPort"
    value = "80"
  }

  values = [
    <<-EOT
    extraArgs:
    - --enable-insecure-login
    ingress:
      hosts:
      - dashboard.${var.domain_name != "" ? var.domain_name : "${var.loadbalancer_ip}.nip.io"}
      tls:
      - secretName: kubernetes-dashboard-tls
        hosts:
        - dashboard.${var.domain_name != "" ? var.domain_name : "${var.loadbalancer_ip}.nip.io"}
      annotations:
        cert-manager.io/cluster-issuer: "lets-encrypt"
    EOT
  ]

  depends_on = [
    kubectl_manifest.cluster_issuer,
    helm_release.ingress_nginx,
    helm_release.cert_manager,
  ]
}

resource "kubectl_manifest" "kubernetes_dashboard_cluster_role_binding" {
  yaml_body  = <<-YAML
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: kubernetes-dashboard
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-admin
    subjects:
    - kind: ServiceAccount
      name: kubernetes-dashboard
      namespace: kubernetes-dashboard
    YAML
  apply_only = true
  depends_on = [helm_release.kubernetes_dashboard]
}

resource "helm_release" "prometheus" {
  count = var.enable_monitoring ? 1 : 0

  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = var.helm_prometheus
  namespace        = "prometheus"
  create_namespace = "true"

  set {
    name  = "server.persistentVolume.size"
    value = "15Gi"
  }
  set {
    name  = "alertmanager.persistentVolume.size"
    value = "5Gi"
  }

  values = [
    <<-EOT
    nodeExporter:
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: CriticalAddonsOnly
        operator: Exists
    EOT
  ]

  depends_on = [
    helm_release.longhorn,
    helm_release.cert_manager
  ]
}

resource "helm_release" "loki" {
  count = var.enable_logging ? 1 : 0

  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = var.helm_loki
  namespace        = "loki"
  create_namespace = "true"

  values = [
    <<-EOT
    config:
      compactor:
        retention_enabled: true
    persistence:
      enabled: true
      size: 20Gi
    EOT
  ]

  depends_on = [
    helm_release.longhorn,
    helm_release.cert_manager
  ]
}

resource "helm_release" "promtail" {
  count = var.enable_logging ? 1 : 0

  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = var.helm_promtail
  namespace        = "promtail"
  create_namespace = "true"

  values = [
    <<-EOT
    config:
      clients:
      - url: http://loki.loki.svc.cluster.local:3100/loki/api/v1/push

    tolerations:
    - key: node-role.kubernetes.io/master
      operator: Exists
      effect: NoSchedule
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
    - key: CriticalAddonsOnly
      operator: Exists
    EOT
  ]

  depends_on = [helm_release.loki]
}

resource "helm_release" "grafana" {
  count = var.enable_monitoring ? 1 : 0

  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  version          = var.helm_grafana
  namespace        = "grafana"
  create_namespace = "true"

  set {
    name  = "deploymentStrategy.type"
    value = "Recreate"
  }
  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "ingress.enabled"
    value = "true"
  }

  values = [
    <<-EOT
    ingress:
      hosts:
      - grafana.${var.domain_name != "" ? var.domain_name : "${var.loadbalancer_ip}.nip.io"}
      tls:
      - secretName: grafana-tls
        hosts:
        - grafana.${var.domain_name != "" ? var.domain_name : "${var.loadbalancer_ip}.nip.io"}
      annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: "lets-encrypt"

    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
        - name: Prometheus
          type: prometheus
          url: http://prometheus-server.prometheus.svc.cluster.local
          access: proxy
          isDefault: true
        - name: Loki
          type: loki
          url: http://loki.loki.svc.cluster.local:3100

    dashboardProviders:
      dashboardproviders.yaml:
        apiVersion: 1
        providers:
        - name: 'default'
          orgId: 1
          folder: ''
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/default
    dashboards:
      default:
        node-exporter:
          gnetId: 1860
          revision: 27
        cilium:
          url: https://raw.githubusercontent.com/cilium/cilium/${var.cilium_version}/examples/kubernetes/addons/prometheus/files/grafana-dashboards/cilium-dashboard.json
          token: ''
        cilium-operator:
          url: https://raw.githubusercontent.com/cilium/cilium/${var.cilium_version}/examples/kubernetes/addons/prometheus/files/grafana-dashboards/cilium-operator-dashboard.json
          token: ''
        hubble:
          url: https://raw.githubusercontent.com/cilium/cilium/${var.cilium_version}/examples/kubernetes/addons/prometheus/files/grafana-dashboards/hubble-dashboard.json
          token: ''
    EOT
  ]

  depends_on = [
    kubectl_manifest.cluster_issuer,
    helm_release.longhorn,
    helm_release.ingress_nginx,
    helm_release.cert_manager,
    helm_release.prometheus,
    helm_release.loki
  ]
}
