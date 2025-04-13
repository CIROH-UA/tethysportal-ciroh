#https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/19.5.0/submodules/karpenter
/* 
External Node IAM Role (Default)
In the following example, the Karpenter module will create:

An IAM role for service accounts (IRSA) with a narrowly scoped IAM policy for the Karpenter controller to utilize
An IAM instance profile for the nodes created by Karpenter to utilize
Note: This setup will utilize the existing IAM role created by the EKS Managed Node group which means the role is already populated in the aws-auth configmap and no further updates are required.
An SQS queue and Eventbridge event rules for Karpenter to utilize for spot termination handling, capacity rebalancing, etc.
*/
module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
  cluster_name = module.eks.cluster_name

  version = "19.20.0"
  
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]
  create_iam_role = false
  iam_role_arn    = module.eks.eks_managed_node_groups["tethys-core"].iam_role_arn

  tags = {
    Environment = "${var.environment}"
    Terraform   = "true"
  }
}
resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "v0.31.3"

  set {
    name  = "settings.aws.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
    # value = module.karpenter.iam_role_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }
  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }

}
resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      # References cloud provider-specific custom resource, see your cloud provider specific documentation
      providerRef:
        name: default
      requirements:
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["c", "m", "t" ]

        - key: karpenter.k8s.aws/instance-size
          operator: In
          values:
            - small
            - medium
            - large
            - xlarge
            - 2xlarge
        - key: "karpenter.sh/capacity-type" # If not included, the webhook for the AWS cloud provider will default to on-demand
          operator: In
          values: ["on-demand"]
      limits:
        resources:
          cpu: "1000"
          memory: 1000Gi
      consolidation:
        enabled: true

      ttlSecondsUntilExpired: 2592000 # 30 Days = 60 * 60 * 24 * 30 Seconds;

      weight: 10

  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeType: gp3
            volumeSize: 50Gi
            deleteOnTermination: true        
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

