output "efs_id" {
  value = aws_efs_file_system.efs.id
}
output "aws_eip" {
  value = { for k, v in data.aws_eip.nlb : k => v.id }
}
output "vpc_public_subnets" {
  value = module.vpc.public_subnets
}

output "karpenter_node_role_name" {
  value = module.karpenter.node_iam_role_name
}
output "karpenter_instance_profile_name" {
  value = module.karpenter.instance_profile_name
}