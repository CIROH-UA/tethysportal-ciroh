resource "aws_efs_file_system" "efs" {
  creation_token   = "${var.app_name}-${var.environment}-efs"
  performance_mode = "generalPurpose"

  lifecycle_policy {
    transition_to_ia = "AFTER_60_DAYS"
  }

}

resource "aws_security_group" "efs" {
  name        = "${var.app_name}-${var.environment}-efs-sg"
  description = "Allow inbound efs traffic from Kubernetes Subnet"
  vpc_id      = module.vpc.vpc_id

  ingress {
    cidr_blocks = [module.vpc.vpc_cidr_block]
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
  }
  egress {
    cidr_blocks = [module.vpc.vpc_cidr_block]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

}

resource "aws_efs_mount_target" "mount" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = module.vpc.private_subnets[0]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "mount1" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = module.vpc.private_subnets[1]
  security_groups = [aws_security_group.efs.id]
}


data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Trust policy built with the helper to avoid JSON/quoting glitches
data "aws_iam_policy_document" "efs_podidentity_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    # Must match the account that owns the cluster
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    # Scope to *this* cluster’s Pod Identity associations
    # Note: use var.region (no deprecated data.aws_region.name)
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:eks:${var.region}:${data.aws_caller_identity.current.account_id}:podidentityassociation/cluster/${module.eks.cluster_name}/*"
      ]
    }
  }
}

resource "aws_iam_role" "efs_pod_identity" {
  name               = "EKS-PodIdentity-EFS-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.efs_podidentity_trust.json
}

resource "aws_iam_role_policy_attachment" "efs_pod_identity_policy" {
  role       = aws_iam_role.efs_pod_identity.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_eks_pod_identity_association" "efs" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa" # matches the managed add-on’s SA name
  role_arn        = aws_iam_role.efs_pod_identity.arn
}