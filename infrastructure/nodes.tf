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

  catalog_name  = var.vcd_catalog
  template_name = var.vcd_template
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
    "hostname" = "${var.k8s_cluster_name}-bastion"
    "password" = var.k8s_bastion_root_password
    "user-data" = base64encode(templatefile("${path.module}/user_data_bastion.tmpl", {
      "hostname" = "${var.k8s_cluster_name}-bastion"
    }))
  }

  customization {
    force                      = true
    enabled                    = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.k8s_bastion_root_password
    # TODO: or maybe this needs to be done like this: https://github.com/vmware/terraform-provider-vcd/issues/510#issuecomment-843721455
    # initscript = <<-EOT
    # ssh_pwauth: true
    # EOT
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

  catalog_name  = var.vcd_catalog
  template_name = var.vcd_template
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

  # TODO: use guest customization for ssh-keys? maybe even for cloudinit/userdata?
  # guest_properties = {
  #   "instance-id" = var.guest_hostname
  #   "hostname"    = var.guest_hostname
  #   "public-keys" = var.guest-ssh-public-key
  #   "user-data"   = base64encode(file("script.sh"))
  # }
  guest_properties = {
    "hostname" = "${var.k8s_cluster_name}-master-${count.index}"
    "password" = var.k8s_control_plane_root_password
    "user-data" = base64encode(templatefile("${path.module}/user_data_master.tmpl", {
      "hostname" = "${var.k8s_cluster_name}-master-${count.index}"
    }))
  }

  customization {
    enabled                    = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.k8s_control_plane_root_password
    # TODO: or maybe this needs to be done like this: https://github.com/vmware/terraform-provider-vcd/issues/510#issuecomment-843721455
    # initscript = <<-EOT
    # ssh_pwauth: true
    # packages:
    # - open-iscsi
    # runcmd:
    # - systemctl enable iscsid.service
    # - systemctl start iscsid.service
    # EOT
    # TODO: open-iscsi/iscsiadm installation! https://longhorn.io/docs/1.3.0/deploy/install/#using-the-environment-check-script
    # TODO: https://longhorn.io/docs/1.3.0/deploy/install/
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

  catalog_name  = var.vcd_catalog
  template_name = var.vcd_template
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
    "hostname" = "${var.k8s_cluster_name}-worker-${count.index}"
    "password" = var.k8s_worker_root_password
    "user-data" = base64encode(templatefile("${path.module}/user_data_worker.tmpl", {
      "hostname" = "${var.k8s_cluster_name}-worker-${count.index}"
    }))
  }

  customization {
    enabled                    = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.k8s_worker_root_password
    # TODO: or maybe this needs to be done like this: https://github.com/vmware/terraform-provider-vcd/issues/510#issuecomment-843721455
    # initscript = <<-EOT
    # ssh_pwauth: true
    # packages:
    # - open-iscsi
    # runcmd:
    # - systemctl enable iscsid.service
    # - systemctl start iscsid.service
    # EOT
    # TODO: open-iscsi/iscsiadm installation! https://longhorn.io/docs/1.3.0/deploy/install/#using-the-environment-check-script
    # TODO: https://longhorn.io/docs/1.3.0/deploy/install/
  }

  depends_on = [
    vcd_vapp_org_network.k8s_org_network,
    vcd_nsxv_snat.outbound,
    vcd_nsxv_dnat.bastion_ssh,
    vcd_lb_server_pool.k8s_http_pool,
    vcd_lb_server_pool.k8s_https_pool
  ]
}
