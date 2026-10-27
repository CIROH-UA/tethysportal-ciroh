variable "region" {}
variable "profile" {}
variable "cluster_name" {}
variable "app_name" {}
variable "helm_chart" {}
variable "helm_repo" {}
variable "helm_ci_path" {}
variable "environment" {}
variable "single_nat_gate_way" {}
variable "deploy_portal" {
  type    = bool
  default = false
}
variable "kubernetes_version" {
  type        = string
  description = "EKS control plane version. Node groups and Karpenter AMIs follow this."
}
