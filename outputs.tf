output "loadbalancer_ip" {
  value = module.infrastructure.edge_gateway_external_ip
}

resource "local_sensitive_file" "kubeconfig_file" {
  filename        = "kubeconfig"
  content         = module.kubernetes.kubeconfig
  file_permission = "0600"
}

output "cluster_info" {
  value = format(
    "export KUBECONFIG=%s; kubectl cluster-info; kubectl get pods -A",
    local_sensitive_file.kubeconfig_file.filename,
  )
}

output "longhorn_dashboard" {
  value = format(
    "export KUBECONFIG=%s; %s",
    local_sensitive_file.kubeconfig_file.filename,
    module.deployments.longhorn_dashboard,
  )
}

output "kubernetes_dashboard_token" {
  value = format(
    "export KUBECONFIG=%s; %s",
    local_sensitive_file.kubeconfig_file.filename,
    module.deployments.kubernetes_dashboard_token,
  )
}
output "kubernetes_dashboard_url" {
  value = module.deployments.kubernetes_dashboard_url
}

output "grafana_admin_password" {
  value = format(
    "export KUBECONFIG=%s; %s",
    local_sensitive_file.kubeconfig_file.filename,
    module.deployments.grafana_admin_password,
  )
}
output "grafana_url" {
  value = module.deployments.grafana_url
}
