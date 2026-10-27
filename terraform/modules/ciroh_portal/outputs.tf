output "vpc_public_subnets" {
  value = module.vpc.public_subnets
}

output "karpenter_node_role_name" {
  value = module.karpenter.node_iam_role_name
}
output "karpenter_instance_profile_name" {
  value = module.karpenter.instance_profile_name
}
output "vpc_cni_irsa_role_arn" {
  description = "Role the vpc-cni addon assumes. The iam-role-for-service-accounts module appends a unique suffix to its name argument, so the literal name in networking.tf is not the real role name. Read this output rather than composing the ARN by hand."
  value       = module.vpc_cni_irsa.arn
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider backing IRSA trust policies for this cluster."
  value       = module.eks.oidc_provider_arn
}

output "cluster_name" {
  value = module.eks.cluster_name
}
