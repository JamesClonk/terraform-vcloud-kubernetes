output "k8s_control_plane" {
  value = vcd_vapp_vm.k8s_control_plane
}
output "k8s_worker" {
  value = vcd_vapp_vm.k8s_control_plane
}
output "edge_gateway_external_ip" {
  value = data.vcd_edgegateway.k8s.default_external_network_ip
}