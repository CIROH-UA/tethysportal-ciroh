variable "region" {}
variable "profile" {}
variable "cluster_name" {}
variable "app_name" {}
variable "helm_chart" {}
variable "helm_repo" {}
variable "helm_values_file" {}
variable "environment" {}
variable "use_elastic_ips" {}
variable "single_nat_gate_way" {}
variable "deploy_portal" {
  type    = bool
  default = false
}
variable "eips" {
  type = list(string)
  description = "List of Elastic IP IDs"
  default = [] # Optional: Provide a default value if needed
}