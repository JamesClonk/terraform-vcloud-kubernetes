resource "kubectl_manifest" "hairpin_proxy_ns" {
  yaml_body  = <<-YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: hairpin-proxy
    YAML
  apply_only = true
  depends_on = [helm_release.ingress_nginx]
}

resource "kubectl_manifest" "hairpin_proxy_sa" {
  yaml_body  = <<-YAML
    kind: ServiceAccount
    apiVersion: v1
    metadata:
      name: hairpin-proxy-controller-sa
      namespace: hairpin-proxy
    YAML
  apply_only = true
  depends_on = [kubectl_manifest.hairpin_proxy_ns]
}

resource "kubectl_manifest" "hairpin_proxy_cr" {
  yaml_body  = <<-YAML
    kind: ClusterRole
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: hairpin-proxy-controller-cr
    rules:
      - apiGroups:
          - extensions
          - networking.k8s.io
        resources:
          - ingresses
        verbs:
          - get
          - list
          - watch
    YAML
  apply_only = true
  depends_on = [kubectl_manifest.hairpin_proxy_ns]
}

resource "kubectl_manifest" "hairpin_proxy_crb" {
  yaml_body  = <<-YAML
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: hairpin-proxy-controller-crb
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: hairpin-proxy-controller-cr
    subjects:
      - kind: ServiceAccount
        name: hairpin-proxy-controller-sa
        namespace: hairpin-proxy
    YAML
  apply_only = true
  depends_on = [
    kubectl_manifest.hairpin_proxy_cr,
    kubectl_manifest.hairpin_proxy_sa,
  ]
}

resource "kubectl_manifest" "hairpin_proxy_r" {
  yaml_body  = <<-YAML
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: hairpin-proxy-controller-r
      namespace: kube-system
    rules:
      - apiGroups: [""]
        resources:
          - configmaps
        resourceNames:
          - coredns
        verbs:
          - get
          - watch
          - update
    YAML
  apply_only = true
  depends_on = [kubectl_manifest.hairpin_proxy_ns]
}

resource "kubectl_manifest" "hairpin_proxy_rb" {
  yaml_body  = <<-YAML
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: hairpin-proxy-controller-rb
      namespace: kube-system
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: hairpin-proxy-controller-r
    subjects:
      - kind: ServiceAccount
        name: hairpin-proxy-controller-sa
        namespace: hairpin-proxy
    YAML
  apply_only = true
  depends_on = [
    kubectl_manifest.hairpin_proxy_cr,
    kubectl_manifest.hairpin_proxy_sa,
  ]
}

resource "kubectl_manifest" "hairpin_proxy_deploy" {
  yaml_body  = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      labels:
        app: hairpin-proxy-haproxy
      name: hairpin-proxy-haproxy
      namespace: hairpin-proxy
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: hairpin-proxy-haproxy
      template:
        metadata:
          labels:
            app: hairpin-proxy-haproxy
        spec:
          containers:
            - image: compumike/hairpin-proxy-haproxy:0.2.1
              name: main
              env:
              - name: TARGET_SERVER
                value: ingress-controller-ingress-nginx-controller.ingress-nginx.svc.cluster.local
              resources:
                requests:
                  memory: "128Mi"
                  cpu: "25m"
                limits:
                  memory: "256Mi"
                  cpu: "100m"
    YAML
  apply_only = true
  depends_on = [
    kubectl_manifest.hairpin_proxy_sa,
    kubectl_manifest.hairpin_proxy_crb,
    kubectl_manifest.hairpin_proxy_rb
  ]
}

resource "kubectl_manifest" "hairpin_proxy_ctrl" {
  yaml_body  = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      labels:
        app: hairpin-proxy-controller
      name: hairpin-proxy-controller
      namespace: hairpin-proxy
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: hairpin-proxy-controller
      template:
        metadata:
          labels:
            app: hairpin-proxy-controller
        spec:
          serviceAccountName: hairpin-proxy-controller-sa
          securityContext:
            runAsUser: 405
            runAsGroup: 65533
          containers:
            - image: compumike/hairpin-proxy-controller:0.2.1
              name: main
              resources:
                requests:
                  memory: "64Mi"
                  cpu: "25m"
                limits:
                  memory: "128Mi"
                  cpu: "100m"
    YAML
  apply_only = true
  depends_on = [
    kubectl_manifest.hairpin_proxy_sa,
    kubectl_manifest.hairpin_proxy_crb,
    kubectl_manifest.hairpin_proxy_rb,
  ]
}

resource "kubectl_manifest" "hairpin_proxy_svc" {
  yaml_body  = <<-YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: hairpin-proxy
      namespace: hairpin-proxy
    spec:
      selector:
        app: hairpin-proxy-haproxy
      ports:
        - name: http
          protocol: TCP
          port: 80
          targetPort: 80
        - name: https
          protocol: TCP
          port: 443
          targetPort: 443
    YAML
  apply_only = true
  depends_on = [kubectl_manifest.hairpin_proxy_deploy]
}

resource "null_resource" "hairpin_proxy" {
  depends_on = [
    kubectl_manifest.hairpin_proxy_ns,
    kubectl_manifest.hairpin_proxy_sa,
    kubectl_manifest.hairpin_proxy_cr,
    kubectl_manifest.hairpin_proxy_crb,
    kubectl_manifest.hairpin_proxy_r,
    kubectl_manifest.hairpin_proxy_rb,
    kubectl_manifest.hairpin_proxy_deploy,
    kubectl_manifest.hairpin_proxy_ctrl,
    kubectl_manifest.hairpin_proxy_svc,
  ]
}
