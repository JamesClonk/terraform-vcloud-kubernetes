# pre-provisioned vCD edge gateway
data "vcd_edgegateway" "k8s" {
  name = var.vcd_edgegateway
}

# vCD NSX-V network for Kubernetes nodes
resource "vcd_network_routed_v2" "k8s_nodes" {
  name = "k8s_nodes"

  interface_type  = "internal"
  edge_gateway_id = data.vcd_edgegateway.k8s.id
  gateway         = cidrhost(var.k8s_cidr, 1)
  prefix_length   = split("/", var.k8s_cidr)[1]
  dns1            = "1.1.1.1"
  dns2            = "8.8.8.8"

  static_ip_pool {
    start_address = cidrhost(var.k8s_cidr, 20)
    end_address   = cidrhost(var.k8s_cidr, 200)
  }
}

resource "vcd_nsxv_snat" "outbound" {
  edge_gateway = var.vcd_edgegateway

  network_type = "org"
  network_name = vcd_network_routed_v2.k8s_nodes.name

  original_address   = var.k8s_cidr
  translated_address = data.vcd_edgegateway.k8s.default_external_network_ip
}

resource "vcd_nsxv_dnat" "bastion_ssh" {
  edge_gateway = var.vcd_edgegateway

  network_type = "ext"
  network_name = vcd_network_routed_v2.k8s_nodes.name

  original_address = data.vcd_edgegateway.k8s.default_external_network_ip
  original_port    = 2222

  translated_address = cidrhost(var.k8s_cidr, 20)
  translated_port    = 22
  protocol           = "tcp"
}
