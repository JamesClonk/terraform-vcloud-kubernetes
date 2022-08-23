# pre-provisioned vCD edge gateway
data "vcd_edgegateway" "k8s_gateway" {
  name = var.vcd_edgegateway
}

resource "vcd_edgegateway_settings" "k8s_gateway" {
  edge_gateway_id         = data.vcd_edgegateway.k8s_gateway.id
  lb_enabled              = true
  lb_acceleration_enabled = false
  lb_logging_enabled      = false

  fw_enabled                      = true
  fw_default_rule_logging_enabled = false
}

resource "vcd_network_routed_v2" "k8s_network" {
  name = var.k8s_cluster_name

  interface_type  = "internal"
  edge_gateway_id = data.vcd_edgegateway.k8s_gateway.id
  gateway         = cidrhost(var.k8s_cidr, 1)
  prefix_length   = split("/", var.k8s_cidr)[1]
  dns1            = "1.1.1.1"
  dns2            = "8.8.8.8"

  static_ip_pool {
    start_address = cidrhost(var.k8s_cidr, 20)
    end_address   = cidrhost(var.k8s_cidr, 200)
  }

  depends_on = [
    vcd_nsxv_firewall_rule.k8s_internal,
    vcd_nsxv_firewall_rule.k8s_external,
    vcd_nsxv_firewall_rule.k8s_bastion_ssh,
    vcd_nsxv_firewall_rule.k8s_apiserver,
    vcd_nsxv_firewall_rule.k8s_web_ingress,
    vcd_nsxv_firewall_rule.k8s_nodeports
  ]
}

resource "vcd_nsxv_snat" "outbound" {
  edge_gateway = var.vcd_edgegateway

  network_type = "ext"
  network_name = var.vcd_edgegateway

  original_address   = var.k8s_cidr
  translated_address = data.vcd_edgegateway.k8s_gateway.default_external_network_ip
}

resource "vcd_nsxv_dnat" "bastion_ssh" {
  edge_gateway = var.vcd_edgegateway

  network_type = "ext"
  network_name = var.vcd_edgegateway

  original_address = data.vcd_edgegateway.k8s_gateway.default_external_network_ip
  original_port    = 2222

  translated_address = cidrhost(var.k8s_cidr, 20)
  translated_port    = 22
  protocol           = "tcp"
}
