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

  required_version = ">= 1.7.0"
}


module "ciroh_portal" {
  source = "../modules/ciroh_portal"
  # Input Varibles
  region              = "us-east-1"
  profile             = "456531024327"
  cluster_name        = "ciroh-portal-prod"
  kubernetes_version  = "1.36"
  app_name            = "cirohportal"
  environment         = "prod"
  single_nat_gate_way = false
}

# The portal release is deployed by CI (helm_deploy.yml) now. Forget it, don't
# uninstall it: without destroy = false the next apply would remove the portal.
removed {
  from = module.ciroh_portal.helm_release.tethysportal_helm_release
  lifecycle {
    destroy = false
  }
}

# Created by hand on 2026-10-27; adopt it rather than create a second one.
import {
  to = module.ciroh_portal.aws_vpc_endpoint.s3
  id = "vpce-0139ac1cfa57b0b32"
}

# Created with kubectl so the apps could move to gp3 before an apply; adopt it.
import {
  to = module.ciroh_portal.kubernetes_storage_class_v1.gp3
  id = "gp3"
}
