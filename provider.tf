terraform {
  required_version = ">= 1.0"
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.4"
    }
  }
}


provider "helm" {
  kubernetes {
    config_path = var.config_path
  }
}

 provider "kubectl" {
    config_path = var.config_path
}