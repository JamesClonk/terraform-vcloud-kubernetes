resource "vcd_catalog" "k8s_catalog" {
  name = var.vcd_catalog != "" ? var.vcd_catalog : var.k8s_cluster_name

  delete_recursive = "true"
  delete_force     = "true"
}

resource "vcd_catalog_item" "k8s_item" {
  catalog = vcd_catalog.k8s_catalog.name
  name    = var.vcd_template != "" ? var.vcd_template : "${var.k8s_cluster_name}_ubuntu_os_22.04"

  ova_path             = var.vcd_ova_file != "" ? var.vcd_ova_file : "jammy-server-cloudimg-amd64.ova"
  upload_piece_size    = 10
  show_upload_progress = true
}
