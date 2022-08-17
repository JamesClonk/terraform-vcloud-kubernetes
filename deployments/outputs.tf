output "kubernetes_dashboard_token" {
  value = "kubectl -n kubernetes-dashboard create token kubernetes-dashboard"
}
output "kubernetes_dashboard_url" {
  value = "https://dashboard.${var.domain_name != "" ? var.domain_name : "${var.loadbalancer_ip}.nip.io"}"
}
