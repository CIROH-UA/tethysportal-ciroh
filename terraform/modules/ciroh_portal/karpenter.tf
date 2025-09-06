module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.1.0"

  cluster_name = var.cluster_name
  
  namespace       = "karpenter"
  service_account = "karpenter"  
  
  create_iam_role = true

  create_instance_profile = true
  
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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
  version          = "1.6.2"
  namespace        = "karpenter"
  create_namespace = true
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.6.2"
  timeout     = 600
  

  values = [
    <<-EOT
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
    webhook:
      enabled: true
    EOT
  ]

    depends_on = [
      helm_release.karpenter_crds,   # CRDs first
      module.karpenter               # IAM + Pod Identity ready
    ]
}