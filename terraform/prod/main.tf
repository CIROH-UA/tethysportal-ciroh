terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }

  required_version = ">= 1.4.0"
}


module "ciroh_portal" {
  source = "../modules/ciroh_portal"
  # Input Varibles
  region              = "us-east-1"
  profile             = "456531024327"
  cluster_name        = "ciroh-portal-prod"
  app_name            = "cirohportal"
  helm_chart          = "ciroh"
  helm_repo           = "https://docs.ciroh.org/tethysportal-ciroh"
  helm_values_file    = "../../charts/ciroh/ci/prod_aws_values.yaml"
  environment         = "prod"
  single_nat_gate_way = false
  use_elastic_ips     = true
  eips                = ["eipalloc-06eeeb09d3f32a313", "eipalloc-0596c82ab483a5d45"]
}
