variable "k8s_cidr" {
  default = "10.0.80.0/24"
}
variable "k8s_cluster_name" {
  default = "kubernetes"
}
variable "k8s_bastion_ip" {}
variable "k8s_bastion_root_password" {}
variable "k8s_control_plane_root_password" {}
variable "k8s_worker_root_password" {}
variable "k8s_k3s_version" {
  default = "v1.24.3+k3s1"
}
variable "k8s_control_plane_instances" {}
variable "k8s_worker_instances" {}
