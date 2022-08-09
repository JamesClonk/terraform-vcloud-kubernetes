terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.7.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "vcd" {
  url      = var.vcd_api_url
  user     = var.vcd_api_username
  password = var.vcd_api_password
  org      = var.vcd_org
  vdc      = var.vcd_vdc

  auth_type            = "integrated"
  max_retry_timeout    = 120
  allow_unverified_ssl = true
}
