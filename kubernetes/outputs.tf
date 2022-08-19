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
output "kubeconfig" {
  value = module.k3s.kube_config
}
output "kubernetes_ready" {
  value = module.k3s.kubernetes_ready
}
