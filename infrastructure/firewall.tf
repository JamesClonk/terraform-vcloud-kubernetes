resource "vcd_nsxv_firewall_rule" "k8s_internal" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway
  name         = "internal network"

  action = "accept"
  source {
    gateway_interfaces = ["internal"]
  }
  destination {
    gateway_interfaces = ["internal"]
  }
  service {
    protocol = "any"
  }
}

resource "vcd_nsxv_firewall_rule" "k8s_external" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway
  name         = "outbound traffic"

  action = "accept"
  source {
    gateway_interfaces = ["internal"]
  }
  destination {
    gateway_interfaces = ["external"]
  }
  service {
    protocol = "any"
  }
}

resource "vcd_nsxv_firewall_rule" "k8s_network" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway
  name         = "k8s network"

  action = "accept"
  source {
    ip_addresses = ["${var.k8s_cidr}"]
  }
  destination {
    ip_addresses = ["any"]
  }
  service {
    protocol = "any"
  }
}

resource "vcd_nsxv_firewall_rule" "k8s_bastion_ssh" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway
  name         = "bastion host"

  action = "accept"
  source {
    gateway_interfaces = ["external"]
  }
  destination {
    ip_addresses = ["${data.vcd_edgegateway.k8s_gateway.default_external_network_ip}"]
  }
  service {
    protocol = "tcp"
    port     = "2222"
  }
}

resource "vcd_nsxv_firewall_rule" "k8s_apiserver" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway
  name         = "k8s api"

  action = "accept"
  source {
    gateway_interfaces = ["external"]
  }
  destination {
    ip_addresses = ["${data.vcd_edgegateway.k8s_gateway.default_external_network_ip}"]
  }
  service {
    protocol = "tcp"
    port     = "6443"
  }
}

resource "vcd_nsxv_firewall_rule" "k8s_web_ingress" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway
  name         = "k8s web traffic"

  action = "accept"
  source {
    gateway_interfaces = ["external"]
  }
  destination {
    ip_addresses = ["${data.vcd_edgegateway.k8s_gateway.default_external_network_ip}"]
  }
  service {
    protocol = "tcp"
    port     = "80"
  }
  service {
    protocol = "tcp"
    port     = "443"
  }
}

resource "vcd_nsxv_firewall_rule" "k8s_nodeports" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway
  name         = "k8s nodeports"

  action = "accept"
  source {
    gateway_interfaces = ["external"]
  }
  destination {
    ip_addresses = ["${data.vcd_edgegateway.k8s_gateway.default_external_network_ip}"]
  }
  service {
    protocol = "tcp"
    port     = "30000-32767"
  }
  service {
    protocol = "udp"
    port     = "30000-32767"
  }
}
