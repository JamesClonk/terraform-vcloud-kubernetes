resource "vcd_nsxv_firewall_rule" "k8s_nodes_external_egress" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway

  action = "accept"
  source {
    ip_addresses = [var.k8s_cidr]
  }
  destination {
    ip_addresses       = ["any"]
    gateway_interfaces = ["external"]
  }
  service {
    protocol = "any"
  }
}

resource "vcd_nsxv_firewall_rule" "k8s_nodes_internal" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway

  action = "accept"
  source {
    ip_addresses = [var.k8s_cidr]
  }
  destination {
    ip_addresses = [var.k8s_cidr]
  }
  service {
    protocol = "any"
  }
}

resource "vcd_nsxv_firewall_rule" "k8s_nodes_apiserver" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway

  action = "accept"
  source {
    ip_addresses       = ["any"]
    gateway_interfaces = ["external"]
  }
  destination {
    ip_addresses = ["${data.vcd_edgegateway.k8s.default_external_network_ip}"]
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

  action = "accept"
  source {
    ip_addresses       = ["any"]
    gateway_interfaces = ["external"]
  }
  destination {
    ip_addresses = ["${data.vcd_edgegateway.k8s.default_external_network_ip}"]
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

  action = "accept"
  source {
    ip_addresses       = ["any"]
    gateway_interfaces = ["external"]
  }
  destination {
    ip_addresses = ["${data.vcd_edgegateway.k8s.default_external_network_ip}"]
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

resource "vcd_nsxv_firewall_rule" "k8s_deny_ssh" {
  org          = var.vcd_org
  vdc          = var.vcd_vdc
  edge_gateway = var.vcd_edgegateway

  action = "deny"
  source {
    ip_addresses       = ["any"]
    gateway_interfaces = ["external"]
  }
  destination {
    ip_addresses = ["any"]
  }
  service {
    protocol = "tcp"
    port     = "22"
  }
}
