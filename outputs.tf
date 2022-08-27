output "loadbalancer_ip" {
  value = module.infrastructure.edge_gateway_external_ip
}

output "kubeconfig_filename" {
  value = module.kubernetes.kubeconfig.filename
}

output "cluster_info" {
  value = format(
    "export KUBECONFIG=%s; kubectl cluster-info; kubectl get pods -A",
    module.kubernetes.kubeconfig.filename,
  )
}

output "longhorn_dashboard" {
  value = format(
    "export KUBECONFIG=%s; %s",
    module.kubernetes.kubeconfig.filename,
    module.deployments.longhorn_dashboard,
  )
}

output "kubernetes_dashboard_token" {
  value = format(
    "export KUBECONFIG=%s; %s",
    module.kubernetes.kubeconfig.filename,
    module.deployments.kubernetes_dashboard_token,
  )
}
output "kubernetes_dashboard_url" {
  value = module.deployments.kubernetes_dashboard_url
}

output "grafana_admin_password" {
  value = format(
    "export KUBECONFIG=%s; %s",
    module.kubernetes.kubeconfig.filename,
    module.deployments.grafana_admin_password,
  )
}
output "grafana_url" {
  value = module.deployments.grafana_url
}
