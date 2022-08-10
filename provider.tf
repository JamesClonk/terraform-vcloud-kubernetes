terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.5.1"
    }
  }
  required_version = ">= 1.2.0"
}

provider "vcd" {
  url      = var.vcd_api_url
  user     = var.vcd_api_username
  password = var.vcd_api_password
  #token    = var.vcd_token
  org = var.vcd_org
  vdc = var.vcd_vdc

  auth_type            = var.vcd_auth_type
  max_retry_timeout    = 120
  allow_unverified_ssl = true

  logging = var.vcd_logging_enabled
}
