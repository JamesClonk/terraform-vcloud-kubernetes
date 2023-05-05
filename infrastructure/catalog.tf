resource "vcd_catalog" "k8s_catalog" {
  name = var.vcd_catalog != "" ? var.vcd_catalog : var.k8s_cluster_name

  delete_recursive = "true"
  delete_force     = "true"
}

resource "vcd_catalog_item" "k8s_item" {
  catalog = vcd_catalog.k8s_catalog.name
  name    = var.vcd_template != "" ? var.vcd_template : "${var.k8s_cluster_name}_ubuntu_os_22.04"

  ovf_url           = var.vcd_ovf_url
  upload_piece_size = 10
}
