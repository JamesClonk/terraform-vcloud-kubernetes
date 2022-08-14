output "kubernetes_dashboard_token" {
  value = "kubectl -n kubernetes-dashboard create token kubernetes-dashboard"
}
