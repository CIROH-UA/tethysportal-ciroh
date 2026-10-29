# Karpenter 1.6 doesn't support Kubernetes 1.36 (the cluster's version); 1.13+
# does. 21.29.0 of this submodule (the main eks module stays on 21.1.0) adds the
# controller permissions newer Karpenter needs (iam:ListInstanceProfiles,
# ec2:DescribeInstanceStatus). Upgrade notes:
# https://karpenter.sh/docs/upgrading/upgrade-guide/
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.29.0"

  cluster_name = var.cluster_name

  namespace       = "karpenter"
  service_account = "karpenter"

  create_iam_role = true

  create_instance_profile = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ecr_pull_through             = aws_iam_policy.ecr_pull_through.arn
  }

  tags = {
    Environment = "${var.environment}"
    Terraform   = "true"
  }
}

resource "helm_release" "karpenter_crds" {
  name             = "karpenter-crd"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = "1.15.1" # keep in step with the controller below
  namespace        = "karpenter"
  create_namespace = true
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.15.1"
  timeout    = 600


  values = [
    <<-EOT
    replicas: 1
    nodeSelector:
      karpenter.sh/controller: 'true'
    dnsPolicy: Default
    controller:
      env:
        - name: AWS_REGION
          value: ${var.region}    
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    EOT
  ]

  depends_on = [
    helm_release.karpenter_crds, # CRDs first
    module.karpenter             # IAM + Pod Identity ready
  ]
}