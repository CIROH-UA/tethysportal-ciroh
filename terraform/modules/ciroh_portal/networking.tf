
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  # name = "${var.app_name}-ciroh-vpc"
  name = "${var.app_name}-${var.environment}-vpc"
  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets = ["10.0.1.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.2.0/24", "10.0.4.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gate_way
  enable_dns_hostnames = true
  enable_dns_support   = true
  # if using existing elastic ip is needed:
  #https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest#external-nat-gateway-ips
  # reuse_nat_ips       = true             # <= Skip creation of EIPs for the NAT Gateways
  # external_nat_ip_ids = aws_eip.nat.*.id # <= IPs specified here as input to the module

  public_subnet_tags = {
    #https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.5/deploy/subnet_discovery/
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    #https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.5/deploy/subnet_discovery/
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# Free gateway endpoint: S3 (and ECR layer) traffic from the private subnets
# goes direct instead of through the NAT gateways' per-GB charge.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name = "${var.app_name}-${var.environment}-s3"
  }
}
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  # version = "~> 5.0"
  version = "6.2.1"

  name                  = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}
