resource "vcd_vapp" "k8s_vapp" {
  name       = var.k8s_cluster_name
  depends_on = [vcd_network_routed_v2.k8s_network]
}

resource "vcd_vapp_org_network" "k8s_org_network" {
  vapp_name        = vcd_vapp.k8s_vapp.name
  org_network_name = vcd_network_routed_v2.k8s_network.name
}

resource "vcd_vapp_vm" "k8s_bastion" {
  vapp_name = vcd_vapp.k8s_vapp.name
  name      = "${var.k8s_cluster_name}-bastion"

  catalog_name  = vcd_catalog.k8s_catalog.name
  template_name = vcd_catalog_item.k8s_item.name
  memory        = var.k8s_bastion_memory
  cpus          = var.k8s_bastion_cpus
  cpu_cores     = 1

  accept_all_eulas       = true
  power_on               = true
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true

  network {
    type               = "org"
    name               = vcd_network_routed_v2.k8s_network.name
    ip_allocation_mode = "MANUAL"
    ip                 = cidrhost(var.k8s_cidr, 20)
    is_primary         = true
  }

  guest_properties = {
    "guest.hostname" = "${var.k8s_cluster_name}-bastion"
    "hostname"       = "${var.k8s_cluster_name}-bastion"
    "user-data" = base64encode(templatefile("${path.module}/user_data.tmpl", {
      "hostname" = "${var.k8s_cluster_name}-bastion",
      "sshkey"   = var.k8s_ssh_public_key,
      "ip"       = cidrhost(var.k8s_cidr, 20),
      "gateway"  = cidrhost(var.k8s_cidr, 1)
    }))
  }

  depends_on = [
    vcd_vapp_org_network.k8s_org_network,
    vcd_nsxv_snat.outbound,
    vcd_nsxv_dnat.bastion_ssh
  ]
}

resource "vcd_vapp_vm" "k8s_control_plane" {
  count = var.k8s_control_plane_instances

  vapp_name = vcd_vapp.k8s_vapp.name
  name      = "${var.k8s_cluster_name}-master-${count.index}"

  catalog_name  = vcd_catalog.k8s_catalog.name
  template_name = vcd_catalog_item.k8s_item.name
  memory        = var.k8s_control_plane_memory
  cpus          = var.k8s_control_plane_cpus
  cpu_cores     = 1

  accept_all_eulas       = true
  power_on               = true
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true

  override_template_disk {
    bus_type    = "paravirtual"
    size_in_mb  = "40960"
    bus_number  = 0
    unit_number = 0
  }

  network {
    type               = "org"
    name               = vcd_network_routed_v2.k8s_network.name
    ip_allocation_mode = "MANUAL"
    ip                 = cidrhost(var.k8s_cidr, 50 + count.index)
    is_primary         = true
  }

  guest_properties = {
    "guest.hostname" = "${var.k8s_cluster_name}-master-${count.index}"
    "hostname"       = "${var.k8s_cluster_name}-master-${count.index}"
    "user-data" = base64encode(templatefile("${path.module}/user_data.tmpl", {
      "hostname" = "${var.k8s_cluster_name}-master-${count.index}",
      "sshkey"   = var.k8s_ssh_public_key,
      "ip"       = cidrhost(var.k8s_cidr, 50 + count.index),
      "gateway"  = cidrhost(var.k8s_cidr, 1)
    }))
  }

  depends_on = [
    vcd_vapp_org_network.k8s_org_network,
    vcd_nsxv_snat.outbound,
    vcd_nsxv_dnat.bastion_ssh,
    vcd_lb_server_pool.k8s_api_pool
  ]
}

resource "vcd_vapp_vm" "k8s_worker" {
  count = var.k8s_worker_instances

  vapp_name = vcd_vapp.k8s_vapp.name
  name      = "${var.k8s_cluster_name}-worker-${count.index}"

  catalog_name  = vcd_catalog.k8s_catalog.name
  template_name = vcd_catalog_item.k8s_item.name
  memory        = var.k8s_worker_memory
  cpus          = var.k8s_worker_cpus
  cpu_cores     = 1

  accept_all_eulas       = true
  power_on               = true
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true

  override_template_disk {
    bus_type    = "paravirtual"
    size_in_mb  = var.k8s_worker_disk_size
    bus_number  = 0
    unit_number = 0
  }

  network {
    type               = "org"
    name               = vcd_network_routed_v2.k8s_network.name
    ip_allocation_mode = "MANUAL"
    ip                 = cidrhost(var.k8s_cidr, 100 + count.index)
    is_primary         = true
  }

  guest_properties = {
    "guest.hostname" = "${var.k8s_cluster_name}-worker-${count.index}"
    "hostname"       = "${var.k8s_cluster_name}-worker-${count.index}"
    "user-data" = base64encode(templatefile("${path.module}/user_data.tmpl", {
      "hostname" = "${var.k8s_cluster_name}-worker-${count.index}",
      "sshkey"   = var.k8s_ssh_public_key,
      "ip"       = cidrhost(var.k8s_cidr, 100 + count.index),
      "gateway"  = cidrhost(var.k8s_cidr, 1)
    }))
  }

  depends_on = [
    vcd_vapp_org_network.k8s_org_network,
    vcd_nsxv_snat.outbound,
    vcd_nsxv_dnat.bastion_ssh,
    vcd_lb_server_pool.k8s_http_pool,
    vcd_lb_server_pool.k8s_https_pool
  ]
}
