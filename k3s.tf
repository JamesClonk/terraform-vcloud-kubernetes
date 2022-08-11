module "k3s" {
  source  = "xunleii/k3s/module"
  version = "v3.1.0"

  k3s_version    = var.k8s_k3s_version
  drain_timeout  = "300s"
  managed_fields = ["label", "taint"]

  global_flags = [
    "--kubelet-arg cloud-provider=external"
  ]

  servers = {
    for i in range(length(vcd_vapp_vm.k8s_control_plane)) :
    vcd_vapp_vm.k8s_control_plane[i].name => {
      ip = cidrhost(var.net_k8s_cidr, 50 + i)
      connection = {
        user             = "root"
        password         = var.k8s_control_plane_root_password
        bastion_host     = var.net_load_balancer_ip
        bastion_user     = "root"
        bastion_password = var.k8s_bastion_root_password
      }
      flags       = ["--disable-cloud-controller"]
      labels      = { "node.kubernetes.io/type" = "master" }
      annotations = { "server_index" : i }
    }
  }

  agents = {
    for i in range(length(vcd_vapp_vm.k8s_worker)) :
    "${vcd_vapp_vm.k8s_worker[i].name}_node" => {
      name = vcd_vapp_vm.k8s_worker[i].name
      ip   = cidrhost(var.net_k8s_cidr, 100 + i)
      connection = {
        user             = "root"
        password         = var.k8s_worker_root_password
        bastion_host     = var.net_load_balancer_ip
        bastion_user     = "root"
        bastion_password = var.k8s_bastion_root_password
      }
      labels      = { "node.kubernetes.io/pool" = "worker" }
      annotations = { "worker_index" : i }
    }
  }

  depends_on = [
    vcd_vapp_vm.k8s_bastion,
    vcd_vapp_vm.k8s_control_plane,
    vcd_vapp_vm.k8s_worker
  ]
}

# provider "kubernetes" {
#   host                   = module.k3s.kubernetes.api_endpoint
#   cluster_ca_certificate = module.k3s.kubernetes.cluster_ca_certificate
#   client_certificate     = module.k3s.kubernetes.client_certificate
#   client_key             = module.k3s.kubernetes.client_key
# }
