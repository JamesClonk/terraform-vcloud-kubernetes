output "cluster_api_endpoint" {
  value = replace(module.k3s.kubernetes.api_endpoint, cidrhost(var.k8s_cidr, 50), var.loadbalancer_ip)
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
  value = replace(module.k3s.kube_config, cidrhost(var.k8s_cidr, 50), var.loadbalancer_ip)
}
output "kubernetes_ready" {
  value = module.k3s.kubernetes_ready
}
