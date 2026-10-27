terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      # version = ">= 2.9"
      version = ">= 2.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      # version = ">= 2.20"
      version = ">= 2.30.0"
    }
    aws = {
      source  = "hashicorp/aws"
      # version = ">= 5.0"
      version = ">= 6.0.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      # version = ">= 1.7.0"
      version = ">= 1.14.0"
    }
  }

  required_version = ">= 1.5.0"
}


module "ciroh_portal" {
  source = "../modules/ciroh_portal"
  # Input Varibles
  region              = "us-east-1"
  profile             = "456531024327"
  cluster_name        = "ciroh-portal-prod"
  kubernetes_version  = "1.36"
  app_name            = "cirohportal"
  helm_chart          = "ciroh"
  helm_repo           = "https://docs.ciroh.org/tethysportal-ciroh"
  helm_ci_path        = "../../charts/ciroh/ci"
  environment         = "prod"
  single_nat_gate_way = false
}

import {
  to = module.ciroh_portal.aws_vpc_endpoint.s3
  id = "vpce-0139ac1cfa57b0b32"
}
