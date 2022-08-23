output "kubernetes_dashboard_token" {
  value = "kubectl -n kubernetes-dashboard create token kubernetes-dashboard"
}
output "kubernetes_dashboard_url" {
  value = "https://dashboard.${var.domain_name != "" ? var.domain_name : "${var.loadbalancer_ip}.nip.io"}"
}

output "grafana_admin_password" {
  value = "kubectl -n grafana get secret grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d"
}
output "grafana_url" {
  value = "https://grafana.${var.domain_name != "" ? var.domain_name : "${var.loadbalancer_ip}.nip.io"}"
}
