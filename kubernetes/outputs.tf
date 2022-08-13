output "cluster_api_endpoint" {
  value = module.k3s.kubernetes.api_endpoint
}
output "cluster_ca_certificate" {
  value = module.k3s.kubernetes.cluster_ca_certificate
}
output "client_certificate" {
  value = module.k3s.kubernetes.client_certificate
}
output "client_key" {
  value = module.k3s.kubernetes.client_key
}

resource "local_sensitive_file" "kubeconfig_file" {
  filename        = "k3s_kubeconfig"
  content         = module.k3s.kube_config
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
