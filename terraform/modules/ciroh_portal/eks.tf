module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.1.0"

  name    = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  endpoint_public_access  = true
  # No control-plane logs. The module default ships api + audit + authenticator,
  # ~90 GB/month of CloudWatch ingestion that nothing read (GuardDuty's EKS audit
  # monitoring is off too). Turn "audit" back on here when an investigation needs it.
  enabled_log_types = []

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
      # One on-demand baseline node is enough for the Karpenter controller +
      # system pods (cluster runs ~1-2% CPU); the elastic tier is spot via
      # Karpenter. Keep in lockstep with Karpenter replicas:1 (karpenter.tf) so
      # its single controller replica always has a node.
      desired_size    = 1
      min_size        = 1
      max_size        = 3
      # These used to live in eks_managed_node_group_defaults
      # ami_type                   = "AL2023_x86_64_STANDARD"
      ami_type       = "BOTTLEROCKET_x86_64"
      disk_size                  = 40
      iam_role_attach_cni_policy = false
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
