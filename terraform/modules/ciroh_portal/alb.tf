
module "alb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.2.1"

  name = "AWSLoadBalancerController-IRSA"
  attach_load_balancer_controller_policy = true  # module flag supported by the IAM module

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.alb_irsa.arn
    }
  }
}

resource "helm_release" "ingress" {
  name       = "ingress-${var.environment}"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  namespace  = "kube-system"
  version    = "1.13.4" # current chart line
  atomic           = true   # rollback on failure
  cleanup_on_fail  = true   # remove partial resources if an upgrade fails
  set =[
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name = "region"
      value = var.region
    },
    {
      name = "vpcId"
      value = module.vpc.vpc_id
    },
     {
     name  = "serviceAccount.create"
     value = "false"
    },
    {
     name  = "serviceAccount.name"
     value = "aws-load-balancer-controller"
    }
  ] 

}

resource "aws_iam_policy" "worker_policy" {
  name        = "worker-policy-${var.environment}"
  description = "Worker policy for the ALB Ingress"

  policy = file("../modules/ciroh_portal/iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = module.eks.eks_managed_node_groups

  policy_arn = aws_iam_policy.worker_policy.arn
  role       = each.value.iam_role_name
}