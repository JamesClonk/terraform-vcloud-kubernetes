terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.5.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.1.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 2.1.0"
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

provider "helm" {
  kubernetes {
    host                   = var.cluster_api_endpoint
    cluster_ca_certificate = var.cluster_ca_certificate
    client_certificate     = var.client_certificate
    client_key             = var.client_key
  }
}

provider "kubernetes" {
  host                   = var.cluster_api_endpoint
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
}

provider "kubectl" {
  host                   = var.cluster_api_endpoint
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
  load_config_file       = false
  apply_retry_count      = 5
}
