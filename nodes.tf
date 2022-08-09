resource "vcd_vapp" "k8s_nodes" {
  name       = "${var.k8s_cluster_name}_nodes"
  depends_on = ["vcd_network_routed_v2.k8s_nodes"]
}

resource "vcd_vapp_vm" "k8s_nodes" {
  count = var.k8s_node_instances

  vapp_name = vcd_vapp.k8s_nodes.name
  name      = "${var.k8s_cluster_name}-${count.index}"

  catalog_name  = var.vcd_catalog
  template_name = var.vcd_template
  memory        = var.k8s_node_memory
  cpus          = var.k8s_node_cpus
  cpu_cores     = 1

  accept_all_eulas          = true
  power_on                  = true
  network_dhcp_wait_seconds = 300

  network {
    type               = "org"
    name               = vcd_network_routed_v2.k8s_nodes.name
    ip_allocation_mode = "POOL"
    is_primary         = true
  }

  customization {
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.k8s_node_admin_password
  }

  depends_on = ["vcd_network_routed_v2.k8s_nodes", "vcd_vapp.k8s_nodes"]
}
