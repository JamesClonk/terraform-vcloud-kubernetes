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

output "kubernetes_dashboard_token" {
  value = format(
    "export KUBECONFIG=%s; kubectl -n kubernetes-dashboard create token kubernetes-dashboard",
    local_sensitive_file.kubeconfig_file.filename,
  )
}
