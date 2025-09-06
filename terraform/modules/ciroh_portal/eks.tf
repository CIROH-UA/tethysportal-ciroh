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


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.1.0"

  name    = var.cluster_name
  kubernetes_version  = "1.33"

  endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons  = {
    vpc-cni = {
      before_compute               = true
      most_recent                  = true
      service_account_role_arn     = module.vpc_cni_irsa.arn
      resolve_conflicts_on_create  = "OVERWRITE"
    }
    kube-proxy = { most_recent = true, resolve_conflicts_on_create = "OVERWRITE" }
    coredns    = { most_recent = true, resolve_conflicts_on_create = "OVERWRITE" }
    aws-ebs-csi-driver = { most_recent = true, resolve_conflicts_on_create = "OVERWRITE" }
    aws-efs-csi-driver = { most_recent = true, resolve_conflicts_on_create = "OVERWRITE" }
    metrics-server     = { most_recent = true, resolve_conflicts_on_create = "OVERWRITE" }
    eks-pod-identity-agent = { before_compute = true, most_recent = true }
  
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  
  create_cloudwatch_log_group	  = false # first time, we should probably have this as true
  create_node_security_group = false

  eks_managed_node_groups = {
    tethys-core = {
      name            = "tethys-core-group"
      instance_types  = ["c6i.large"]
      desired_size    = 2
      min_size        = 2
      max_size        = 3
      # These used to live in eks_managed_node_group_defaults
      # ami_type                   = "AL2023_x86_64_STANDARD"
      ami_type       = "BOTTLEROCKET_x86_64"
      disk_size                  = 40
      iam_role_attach_cni_policy = false
      iam_role_additional_policies = {
        eks_node_efs = resource.aws_iam_policy.node_efs_policy.arn
      }
      labels = {
        # Used to ensure Karpenter runs on nodes that it does not manage
        "karpenter.sh/controller" = "true"
      }
    }
    
  }


  tags = {

    "karpenter.sh/discovery" = var.cluster_name
    Environment              = var.environment
    Terraform                = "true"
  }


}
