
data "aws_availability_zones" "available" {}

data "aws_eip" "nlb" {
  count = var.use_elastic_ips ? "${length(var.eips)}" : 0
  id    = element(var.eips, count.index)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  # version = "3.19.0"
  version = "5.19.0"
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
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

# Elastic IP created in the networking module
# data "aws_eip" "nlb" {
#   # The following for_each line: https://discuss.hashicorp.com/t/the-for-each-value-depends-on-resource-attributes-that-cannot-be-determined-until-apply/25016/4
#   for_each   = { for i, val in module.vpc.nat_public_ips : i => val }
#   public_ip  = each.value
#   depends_on = [helm_release.tethysportal_helm_release, module.vpc]
# }


# Create Load Balancer of type Network Load Balancer with subnet mapping
resource "aws_lb" "nlb" {
  count              = var.use_elastic_ips ? 1 : 0
  name               = "${var.app_name}-${var.environment}-nlb"
  internal           = false
  load_balancer_type = "network"


  dynamic "subnet_mapping" {
    for_each = [for i in range(length(module.vpc.public_subnets)) : {
      subnet_id     = module.vpc.public_subnets[i]
      allocation_id = data.aws_eip.nlb[i].id
      # allocation_id = aws_eip.nat[i].id

    }]
    content {
      subnet_id     = subnet_mapping.value.subnet_id
      allocation_id = subnet_mapping.value.allocation_id
    }
  }

  depends_on = [helm_release.tethysportal_helm_release]

}

# Create Load Balancer of type Network Load Balancer without subnet mapping
resource "aws_lb" "nlb-dev" {
  count              = var.use_elastic_ips ? 0 : 1
  name               = "${var.app_name}-${var.environment}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets

  depends_on = [helm_release.tethysportal_helm_release]

}


# Listener rule for HTTP traffic on each of the ALBs
# It might help:https://medium.com/@sampark02/application-load-balancer-and-target-group-attachment-using-terraform-d212ce8a38a0
resource "aws_lb_listener" "nlb" {
  load_balancer_arn = var.use_elastic_ips ? aws_lb.nlb[0].arn : aws_lb.nlb-dev[0].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg.arn
  }
  depends_on = [helm_release.tethysportal_helm_release]
}


# # Listener rule for HTTPS traffic on each of the ALBs
# # It might help:https://medium.com/@sampark02/application-load-balancer-and-target-group-attachment-using-terraform-d212ce8a38a0
resource "aws_lb_listener" "nlb_https" {
  load_balancer_arn = var.use_elastic_ips ? aws_lb.nlb[0].arn : aws_lb.nlb-dev[0].arn
  port              = "443"
  protocol          = "TCP"
  # ssl_policy       = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  # certificate_arn   = "arn:aws:acm:us-east-1:456531024327:certificate/7db78d8f-2148-4af2-a239-6e9a2445dbe7"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg_https.arn
  }
  depends_on = [helm_release.tethysportal_helm_release]
}



# It is a must in order to have the load balancer type application that the ALB AWS creates when the chart is deployed
#https://discuss.hashicorp.com/t/how-to-extract-the-arn-of-a-aws-lb-using-a-tag-that-has-in-it/45277/4
data "aws_lb" "alb_listener_details" {
  tags = {
    #for some reason the cluster name does not work
    # "elbv2.k8.aws/cluster"     = module.eks.cluster_name
    "ingress.k8s.aws/resource" = "LoadBalancer"
    "ingress.k8s.aws/stack"    = "${var.app_name}/${var.app_name}-${var.environment}"
  }
  ## First the helm chart of the portal needs to be deployed
  # For some reason we need some sleeping time for the data tag to get the aws_lb created by the helm realease
  # more details here https://github.com/hashicorp/terraform-provider-aws/issues/20489#issuecomment-1578428056
  depends_on = [helm_release.tethysportal_helm_release]

}
# if the above does not work the following below can work:
# More info here: https://github.com/hashicorp/terraform-provider-aws/issues/12265#issuecomment-833361834



# Create NLB target group that forwards traffic to alb
# https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_CreateTargetGroup.html
resource "aws_lb_target_group" "nlb_tg" {
  name        = "${var.app_name}-${var.environment}-alb"
  port        = 80
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "alb"
  depends_on  = [helm_release.tethysportal_helm_release]
  health_check {
    timeout             = "10"
    interval            = "20"
    path                = "/"
    unhealthy_threshold = "2"
    healthy_threshold   = "3"
  }
}
resource "aws_lb_target_group" "nlb_tg_https" {
  name        = "${var.app_name}-${var.environment}-alb-https"
  port        = 443
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "alb"
  depends_on  = [helm_release.tethysportal_helm_release]
  health_check {
    timeout             = "10"
    interval            = "20"
    path                = "/"
    unhealthy_threshold = "2"
    healthy_threshold   = "3"
  }
}

# Create target group attachment
# More details: https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_TargetDescription.html
# https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_RegisterTargets.html
resource "aws_lb_target_group_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.nlb_tg.arn
  # attach the ALB to this target group
  target_id = data.aws_lb.alb_listener_details.arn
  #   target_id = data.aws_resourcegroupstaggingapi_resources.load_balancer.resource_tag_mapping_list[0].resource_arn
  #  If the target type is alb, the targeted Application Load Balancer must have at least one listener whose port matches the target group port.
  port       = 80
  depends_on = [helm_release.tethysportal_helm_release]

}
resource "aws_lb_target_group_attachment" "tg_attachment_https" {
  target_group_arn = aws_lb_target_group.nlb_tg_https.arn
  # attach the ALB to this target group
  target_id = data.aws_lb.alb_listener_details.arn
  #   target_id = data.aws_resourcegroupstaggingapi_resources.load_balancer.resource_tag_mapping_list[0].resource_arn
  #  If the target type is alb, the targeted Application Load Balancer must have at least one listener whose port matches the target group port.
  port       = 443
  depends_on = [helm_release.tethysportal_helm_release]

}
