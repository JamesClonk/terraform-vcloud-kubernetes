resource "time_sleep" "wait_for_kubernetes" {
  depends_on      = [module.k3s.kubernetes_ready]
  create_duration = "60s"
}

resource "null_resource" "k8s_cilium_install" {
  depends_on = [time_sleep.wait_for_kubernetes]
  triggers = {
    on_new_k3s_version        = var.k3s_version
    on_new_cilium_version     = var.cilium_version
    on_new_cilium_cli_version = var.cilium_cli_version
  }

  connection {
    type                = "ssh"
    host                = cidrhost(var.k8s_cidr, 50)
    user                = var.k8s_control_plane_username
    private_key         = var.k8s_ssh_private_key
    bastion_host        = var.k8s_bastion_ip
    bastion_port        = var.k8s_bastion_port
    bastion_user        = var.k8s_bastion_username
    bastion_private_key = var.k8s_ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
      set -e
      set -o pipefail

      mkdir -p ~/.kube || true
      sed 's/127.0.0.1/${var.loadbalancer_ip}/g' /etc/rancher/k3s/k3s.yaml > ~/.kube/config
      export KUBECONFIG=~/.kube/config

      if [ ! -f "/usr/local/bin/cilium" ]; then
        # download cilium cli
        curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${var.cilium_cli_version}/cilium-linux-amd64.tar.gz{,.sha256sum}
        sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
        sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
        rm -f cilium-linux-amd64.tar.gz{,.sha256sum}
      fi

      # install cilium
      cilium install --restart-unmanaged-pods --wait --wait-duration 15m

      # enable hubble observability, with UI
      cilium hubble enable --ui --wait

      # check status
      cilium status --wait

      # test connectivity
      cilium connectivity test --timestamp
      EOT
    ]
  }
}

resource "null_resource" "k8s_cilium_status" {
  depends_on = [null_resource.k8s_cilium_install]
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type                = "ssh"
    host                = cidrhost(var.k8s_cidr, 50)
    user                = var.k8s_control_plane_username
    private_key         = var.k8s_ssh_private_key
    bastion_host        = var.k8s_bastion_ip
    bastion_port        = var.k8s_bastion_port
    bastion_user        = var.k8s_bastion_username
    bastion_private_key = var.k8s_ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
      set -e
      set -o pipefail

      export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

      if [ ! -f "/usr/local/bin/cilium" ]; then
        # download cilium cli
        curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${var.cilium_cli_version}/cilium-linux-amd64.tar.gz{,.sha256sum}
        sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
        sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
        rm -f cilium-linux-amd64.tar.gz{,.sha256sum}
      fi

      # check status
      cilium status --wait
      EOT
    ]
  }
}
