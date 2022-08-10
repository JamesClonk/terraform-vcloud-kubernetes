resource "vcd_lb_app_profile" "tcp" {
  edge_gateway = var.vcd_edgegateway
  name         = "tcp-app-profile"
  type         = "tcp"
}

resource "vcd_lb_app_profile" "http" {
  edge_gateway = var.vcd_edgegateway
  name         = "http-app-profile"
  type         = "http"
}

resource "vcd_lb_service_monitor" "k8s_monitor" {
  edge_gateway = var.vcd_edgegateway
  name         = "http-monitor"
  type         = "http"

  interval    = "5"
  timeout     = "20"
  max_retries = "3"
  method      = "GET"
  url         = "/health"
}

resource "vcd_lb_server_pool" "k8s_http_pool" {
  edge_gateway = var.vcd_edgegateway
  name         = "k8s-http-pool"

  algorithm           = "round-robin"
  enable_transparency = "true"
  monitor_id          = vcd_lb_service_monitor.k8s_monitor.id

  dynamic "member" {
    for_each = range(0, var.k8s_node_instances)

    content {
      condition    = "enabled"
      name         = "${var.k8s_cluster_name}-${member.value}"
      ip_address   = cidrhost(var.net_k8s_cidr, 100 + member.value)
      port         = 80
      monitor_port = 80
      weight       = 1
    }
  }
}

resource "vcd_lb_server_pool" "k8s_https_pool" {
  edge_gateway = var.vcd_edgegateway
  name         = "k8s-https-pool"

  algorithm           = "round-robin"
  enable_transparency = "true"
  monitor_id          = vcd_lb_service_monitor.k8s_monitor.id

  dynamic "member" {
    for_each = range(0, var.k8s_node_instances)

    content {
      condition    = "enabled"
      name         = "${var.k8s_cluster_name}-${member.value}"
      ip_address   = cidrhost(var.net_k8s_cidr, 100 + member.value)
      port         = 443
      monitor_port = 443
      weight       = 1
    }
  }
}
