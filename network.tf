# pre-provisioned vCD edge gateway
data "vcd_edgegateway" "k8s" {
  name = var.vcd_edgegateway
  org  = var.vcd_org
  vdc  = var.vcd_vdc
}

# vCD network for Kubernetes nodes
resource "vcd_network_routed" "k8s_nodes" {
  name = "k8s_nodes"

  interface_type = "internal"
  edge_gateway   = data.vcd_edgegateway.k8s.id
  gateway        = cidrhost(var.net_k8s_cidr, 1)
  prefix_length  = split("/", var.net_k8s_cidr)[1]
  dns1           = "1.1.1.1"
  dns2           = "8.8.8.8"

  static_ip_pool {
    start_address = cidrhost(var.net_k8s_cidr, 100)
    end_address   = cidrhost(var.net_k8s_cidr, 150)
  }
}
