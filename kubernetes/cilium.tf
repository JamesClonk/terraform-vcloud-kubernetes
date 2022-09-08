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
      #!/bin/bash
      set -e
      set -o pipefail

      mkdir -p ~/.kube || true
      # sed 's/127.0.0.1/${cidrhost(var.k8s_cidr, 50)}/g' /etc/rancher/k3s/k3s.yaml > ~/.kube/config
      sed 's/127.0.0.1/kubernetes.default.svc.cluster.local/g' /etc/rancher/k3s/k3s.yaml > ~/.kube/config
      export KUBECONFIG=~/.kube/config
      grep 'kubernetes.default.svc.cluster.local' /etc/hosts >/dev/null || sudo sh -c 'echo "${cidrhost(var.k8s_cidr, 50)} kubernetes.default.svc.cluster.local" >> /etc/hosts'

      if [ ! -f "/usr/local/bin/cilium" ]; then
        # download cilium cli
        curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${var.cilium_cli_version}/cilium-linux-amd64.tar.gz{,.sha256sum}
        sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
        sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
        rm -f cilium-linux-amd64.tar.gz{,.sha256sum}
      fi

      # install cilium
      set +e
      cilium install --version "${var.cilium_version}" --restart-unmanaged-pods --wait --wait-duration 15m 2>&1 | tee cilium_output.txt
      CILIUM_EXITCODE=$?
      set -e
      if [[ "$CILIUM_EXITCODE" -ne 0 ]]; then
        grep 'secrets "hubble-server-certs" already exists' cilium_output.txt 1>/dev/null
      fi
      rm -f cilium_output.txt || true

      # operator ready?
      kubectl wait --for condition=available deploy --all --timeout=240s -n "kube-system" | grep 'cilium-operator'

      # enable hubble observability, with UI
      set +e
      cilium hubble enable --ui --wait 2>&1 | tee hubble_output.txt
      HUBBLE_EXITCODE=$?
      set -e
      if [[ "$HUBBLE_EXITCODE" -ne 0 ]]; then
        grep 'services "hubble-peer" already exists' hubble_output.txt 1>/dev/null
      fi
      rm -f hubble_output.txt || true

      # check status
      cilium status --wait

      # # test connectivity
      # cilium connectivity test --timestamp
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
      #!/bin/bash
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
