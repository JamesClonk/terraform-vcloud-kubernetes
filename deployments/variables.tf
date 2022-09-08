variable "cluster_api_endpoint" {}
variable "cluster_ca_certificate" {}
variable "client_certificate" {}
variable "client_key" {}
variable "kubernetes_ready" {}
variable "cilium_ready" {}

variable "domain_name" {
  default = ""
}
variable "loadbalancer_ip" {}
variable "enable_monitoring" {}
variable "enable_logging" {}

variable "helm_longhorn_version" {}
variable "helm_ingress_nginx_version" {}
variable "helm_cert_manager_version" {}
variable "helm_kubernetes_dashboard_version" {}
variable "helm_prometheus" {}
variable "helm_loki" {}
variable "helm_promtail" {}
variable "helm_grafana" {}
