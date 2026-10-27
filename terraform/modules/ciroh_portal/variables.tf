variable "region" {}
variable "profile" {}
variable "cluster_name" {}
variable "app_name" {}
variable "environment" {}
variable "single_nat_gate_way" {}
variable "kubernetes_version" {
  type        = string
  description = "EKS control plane version. Node groups and Karpenter AMIs follow this."
}
