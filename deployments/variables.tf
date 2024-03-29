variable "cluster_api_endpoint" {}
variable "cluster_ca_certificate" {}
variable "client_certificate" {}
variable "client_key" {}
variable "kubernetes_summary" {}
variable "kubernetes_ready" {}
variable "cilium_install_ready" {}
variable "cilium_status_ready" {}

variable "domain_name" {
  default = ""
}
variable "lets_encrypt_server" {}
variable "loadbalancer_ip" {}
variable "enable_monitoring" {}
variable "enable_logging" {}
variable "enable_automatic_node_reboot" {}

variable "cilium_version" {}
variable "helm_longhorn_version" {}
variable "helm_kured_version" {}
variable "helm_ingress_nginx_version" {}
variable "helm_cert_manager_version" {}
variable "helm_kubernetes_dashboard_version" {}
variable "helm_prometheus" {}
variable "helm_loki" {}
variable "helm_promtail" {}
variable "helm_grafana" {}
