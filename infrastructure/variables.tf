variable "vcd_api_url" {}
variable "vcd_api_username" {}
variable "vcd_api_password" {}
variable "vcd_token" {
  default = ""
}
variable "vcd_auth_type" {
  default = "integrated"
}
variable "vcd_logging_enabled" {
  default = false
}
variable "vcd_org" {}
variable "vcd_vdc" {}
variable "vcd_catalog" {}
variable "vcd_template" {}
variable "vcd_edgegateway" {}

variable "k8s_cidr" {
  default = "10.0.80.0/24"
}
variable "k8s_cluster_name" {
  default = "kubernetes"
}
variable "k8s_bastion_root_password" {}
variable "k8s_bastion_memory" {
  default = 1024
}
variable "k8s_bastion_cpus" {
  default = 1
}
variable "k8s_control_plane_root_password" {}
variable "k8s_control_plane_instances" {
  default = 3
}
variable "k8s_control_plane_memory" {
  default = 2048
}
variable "k8s_control_plane_cpus" {
  default = 2
}
variable "k8s_worker_root_password" {}
variable "k8s_worker_instances" {
  default = 3
}
variable "k8s_worker_memory" {
  default = 8192
}
variable "k8s_worker_cpus" {
  default = 4
}
variable "k8s_worker_disk_size" {
  default = 245760
}
