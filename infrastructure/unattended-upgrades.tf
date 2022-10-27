resource "null_resource" "k8s_bastion_automatic_upgrades" {
  triggers = {
    on_automatic_upgrade_change = var.k8s_automatically_upgrade_os
  }

  connection {
    type        = "ssh"
    user        = "kubernetes"
    private_key = var.k8s_ssh_private_key
    host        = data.vcd_edgegateway.k8s_gateway.default_external_network_ip
    port        = 2222
    timeout     = "15m"
  }

  provisioner "file" {
    destination = "/tmp/upgrades.sh"
    content     = <<-EOT
      #!/bin/bash

      cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
      Unattended-Upgrade::Allowed-Origins {
              "$${distro_id}:$${distro_codename}";
              "$${distro_id}:$${distro_codename}-security";
              // Extended Security Maintenance; doesn't necessarily exist for
              // every release and this system may not have it installed, but if
              // available, the policy for updates is such that unattended-upgrades
              // should also install from here by default.
              "$${distro_id}ESMApps:$${distro_codename}-apps-security";
              "$${distro_id}ESM:$${distro_codename}-infra-security";
      //      "$${distro_id}:$${distro_codename}-updates";
      //      "$${distro_id}:$${distro_codename}-proposed";
      //      "$${distro_id}:$${distro_codename}-backports";
      };
      EOF

      cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
      APT::Periodic::Update-Package-Lists "${var.k8s_automatically_upgrade_os ? 1 : 0}";
      APT::Periodic::Unattended-Upgrade "${var.k8s_automatically_upgrade_os ? 1 : 0}";
      EOF

      crontab << EOF
      02 02 * * * /sbin/shutdown -r
      EOF

      systemctl restart unattended-upgrades
      EOT
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/upgrades.sh",
      "sudo /tmp/upgrades.sh",
    ]
  }

  depends_on = [
    vcd_vapp_vm.k8s_bastion,
    vcd_nsxv_dnat.bastion_ssh
  ]
}

resource "null_resource" "k8s_control_plane_automatic_upgrades" {
  count = var.k8s_control_plane_instances

  triggers = {
    on_automatic_upgrade_change = var.k8s_automatically_upgrade_os
  }

  connection {
    type                = "ssh"
    user                = "kubernetes"
    private_key         = var.k8s_ssh_private_key
    host                = cidrhost(var.k8s_node_cidr, 50 + count.index)
    bastion_host        = data.vcd_edgegateway.k8s_gateway.default_external_network_ip
    bastion_port        = 2222
    bastion_user        = "kubernetes"
    bastion_private_key = var.k8s_ssh_private_key
    timeout             = "15m"
  }

  provisioner "file" {
    destination = "/tmp/upgrades.sh"
    content     = <<-EOT
      #!/bin/bash

      cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
      Unattended-Upgrade::Allowed-Origins {
              "$${distro_id}:$${distro_codename}";
              "$${distro_id}:$${distro_codename}-security";
              // Extended Security Maintenance; doesn't necessarily exist for
              // every release and this system may not have it installed, but if
              // available, the policy for updates is such that unattended-upgrades
              // should also install from here by default.
              "$${distro_id}ESMApps:$${distro_codename}-apps-security";
              "$${distro_id}ESM:$${distro_codename}-infra-security";
      //      "$${distro_id}:$${distro_codename}-updates";
      //      "$${distro_id}:$${distro_codename}-proposed";
      //      "$${distro_id}:$${distro_codename}-backports";
      };
      EOF

      cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
      APT::Periodic::Update-Package-Lists "${var.k8s_automatically_upgrade_os ? 1 : 0}";
      APT::Periodic::Unattended-Upgrade "${var.k8s_automatically_upgrade_os ? 1 : 0}";
      EOF

      systemctl restart unattended-upgrades
      EOT
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/upgrades.sh",
      "sudo /tmp/upgrades.sh",
    ]
  }

  depends_on = [
    vcd_vapp_vm.k8s_control_plane,
    vcd_nsxv_dnat.bastion_ssh
  ]
}

resource "null_resource" "k8s_worker_automatic_upgrades" {
  count = var.k8s_worker_instances

  triggers = {
    on_automatic_upgrade_change = var.k8s_automatically_upgrade_os
  }

  connection {
    type                = "ssh"
    user                = "kubernetes"
    private_key         = var.k8s_ssh_private_key
    host                = cidrhost(var.k8s_node_cidr, 100 + count.index)
    bastion_host        = data.vcd_edgegateway.k8s_gateway.default_external_network_ip
    bastion_port        = 2222
    bastion_user        = "kubernetes"
    bastion_private_key = var.k8s_ssh_private_key
    timeout             = "15m"
  }

  provisioner "file" {
    destination = "/tmp/upgrades.sh"
    content     = <<-EOT
      #!/bin/bash

      cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
      Unattended-Upgrade::Allowed-Origins {
              "$${distro_id}:$${distro_codename}";
              "$${distro_id}:$${distro_codename}-security";
              // Extended Security Maintenance; doesn't necessarily exist for
              // every release and this system may not have it installed, but if
              // available, the policy for updates is such that unattended-upgrades
              // should also install from here by default.
              "$${distro_id}ESMApps:$${distro_codename}-apps-security";
              "$${distro_id}ESM:$${distro_codename}-infra-security";
      //      "$${distro_id}:$${distro_codename}-updates";
      //      "$${distro_id}:$${distro_codename}-proposed";
      //      "$${distro_id}:$${distro_codename}-backports";
      };
      EOF

      cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
      APT::Periodic::Update-Package-Lists "${var.k8s_automatically_upgrade_os ? 1 : 0}";
      APT::Periodic::Unattended-Upgrade "${var.k8s_automatically_upgrade_os ? 1 : 0}";
      EOF

      systemctl restart unattended-upgrades
      EOT
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/upgrades.sh",
      "sudo /tmp/upgrades.sh",
    ]
  }

  depends_on = [
    vcd_vapp_vm.k8s_worker,
    vcd_nsxv_dnat.bastion_ssh
  ]
}
