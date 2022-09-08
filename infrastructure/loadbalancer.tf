resource "vcd_lb_app_profile" "tcp" {
  edge_gateway = var.vcd_edgegateway
  name         = "tcp-app-profile"
  type         = "tcp"
}

# resource "vcd_lb_app_profile" "http" {
#   edge_gateway = var.vcd_edgegateway
#   name         = "http-app-profile"
#   type         = "http"
# }

resource "vcd_lb_service_monitor" "k8s_tcp_monitor" {
  edge_gateway = var.vcd_edgegateway
  name         = "k8s-tcp-monitor"
  type         = "tcp"

  interval    = "5"
  timeout     = "20"
  max_retries = "3"
}

# resource "vcd_lb_service_monitor" "k8s_http_monitor" {
#   edge_gateway = var.vcd_edgegateway
#   name         = "k8s-http-monitor"
#   type         = "http"

#   interval    = "5"
#   timeout     = "20"
#   max_retries = "3"
#   method      = "GET"
#   url         = "/"
#   expected    = "HTTP/1.1"
# }

# resource "vcd_lb_service_monitor" "k8s_https_monitor" {
#   edge_gateway = var.vcd_edgegateway
#   name         = "k8s-https-monitor"
#   type         = "https"

#   interval    = "5"
#   timeout     = "20"
#   max_retries = "3"
#   method      = "GET"
#   url         = "/"
# }

resource "vcd_lb_server_pool" "k8s_api_pool" {
  edge_gateway = var.vcd_edgegateway
  name         = "k8s-api-pool"

  algorithm           = "round-robin"
  enable_transparency = "true"
  monitor_id          = vcd_lb_service_monitor.k8s_tcp_monitor.id

  dynamic "member" {
    for_each = range(0, var.k8s_control_plane_instances)

    content {
      condition    = "enabled"
      name         = "${var.k8s_cluster_name}-${member.value}"
      ip_address   = cidrhost(var.k8s_node_cidr, 50 + member.value)
      port         = 6443
      monitor_port = 6443
      weight       = 1
    }
  }
}

resource "vcd_lb_server_pool" "k8s_http_pool" {
  edge_gateway = var.vcd_edgegateway
  name         = "k8s-http-pool"

  algorithm           = "round-robin"
  enable_transparency = "true"
  monitor_id          = vcd_lb_service_monitor.k8s_tcp_monitor.id

  dynamic "member" {
    for_each = range(0, var.k8s_worker_instances)

    content {
      condition    = "enabled"
      name         = "${var.k8s_cluster_name}-${member.value}"
      ip_address   = cidrhost(var.k8s_node_cidr, 100 + member.value)
      port         = 30080
      monitor_port = 30080
      weight       = 1
    }
  }
}

resource "vcd_lb_server_pool" "k8s_https_pool" {
  edge_gateway = var.vcd_edgegateway
  name         = "k8s-https-pool"

  algorithm           = "round-robin"
  enable_transparency = "true"
  monitor_id          = vcd_lb_service_monitor.k8s_tcp_monitor.id

  dynamic "member" {
    for_each = range(0, var.k8s_worker_instances)

    content {
      condition    = "enabled"
      name         = "${var.k8s_cluster_name}-${member.value}"
      ip_address   = cidrhost(var.k8s_node_cidr, 100 + member.value)
      port         = 30443
      monitor_port = 30443
      weight       = 1
    }
  }
}

resource "vcd_lb_virtual_server" "k8s_api_vs" {
  edge_gateway = var.vcd_edgegateway
  name         = "k8s-api-vs"

  ip_address     = data.vcd_edgegateway.k8s_gateway.default_external_network_ip
  protocol       = "tcp"
  port           = 6443
  app_profile_id = vcd_lb_app_profile.tcp.id
  server_pool_id = vcd_lb_server_pool.k8s_api_pool.id
}

resource "vcd_lb_virtual_server" "k8s_http_vs" {
  edge_gateway = var.vcd_edgegateway
  name         = "k8s-http-vs"

  ip_address     = data.vcd_edgegateway.k8s_gateway.default_external_network_ip
  protocol       = "tcp"
  port           = 80
  app_profile_id = vcd_lb_app_profile.tcp.id
  server_pool_id = vcd_lb_server_pool.k8s_http_pool.id
}

resource "vcd_lb_virtual_server" "k8s_https_vs" {
  edge_gateway = var.vcd_edgegateway
  name         = "k8s-https-vs"

  ip_address     = data.vcd_edgegateway.k8s_gateway.default_external_network_ip
  protocol       = "tcp"
  port           = 443
  app_profile_id = vcd_lb_app_profile.tcp.id
  server_pool_id = vcd_lb_server_pool.k8s_https_pool.id
}
