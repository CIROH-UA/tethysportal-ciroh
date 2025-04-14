module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.35.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true
  # Shown just for connection between cluster and Karpenter sub-module below
  # We will rely only on the cluster security group created by the EKS service
  # See note below for `tags`
  create_cluster_security_group = false
  create_node_security_group    = false
  
  create_cloudwatch_log_group	  = false # first time, we should probably have this as true

  eks_managed_node_group_defaults = {
    ami_type                   = "AL2_x86_64"
    iam_role_attach_cni_policy = true
    iam_role_additional_policies = {
      eks_node_efs = resource.aws_iam_policy.node_efs_policy.arn
    }
  }

  eks_managed_node_groups = {
    tethys-core = {
      name           = "tethys-core-group"
      instance_types = ["c5.large"]
      desired_size   = 1
      min_size       = 1
      max_size       = 2
      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
      use_custom_launch_template = false
      disk_size                  = 40
      #   tags = {
      #       # NOTE - if creating multiple security groups with this module, only tag the
      #       # security group that Karpenter should utilize with the following tag
      #       # (i.e. - at most, only one security group should have this tag in your account)
      #       "karpenter.sh/discovery" = var.cluster_name
      #     }
    }


  }

  tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = var.cluster_name
  }
}
resource "aws_iam_policy" "node_efs_policy" {
  name        = "eks_node_efs-${var.app_name}-${var.environment}"
  path        = "/"
  description = "Policy for EFKS nodes to use EFS"

  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:CreateAccessPoint",
          "elasticfilesystem:DeleteAccessPoint",
          "ec2:DescribeAvailabilityZones"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : ""
      }
    ],
    "Version" : "2012-10-17"
    }
  )
}
