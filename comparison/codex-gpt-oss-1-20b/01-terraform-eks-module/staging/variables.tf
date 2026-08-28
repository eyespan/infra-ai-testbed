variable "aws_region" {
  type        = string
  description = "AWS region selected by the environment owner; no default is supplied."
}
variable "environment" {
  type        = string
  description = "Environment tag value, supplied by the caller."
}
variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}
variable "kubernetes_version" {
  type        = string
  description = "Currently supported EKS Kubernetes version selected by the caller."
}
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR."
}
variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}
variable "desired_capacity" {
  type    = number
  default = 3
}
variable "min_capacity" {
  type    = number
  default = 1
}
variable "max_capacity" {
  type    = number
  default = 5
}
variable "cloudwatch_log_kms_key_id" {
  type        = string
  description = "Existing approved CloudWatch Logs KMS key ARN or ID."
}
variable "secrets_kms_key_arn" {
  type        = string
  description = "Existing approved KMS key ARN for Kubernetes Secret encryption."
}
variable "irsa_namespace" {
  type        = string
  description = "Namespace for the scoped example workload identity."
}
variable "irsa_service_account_name" {
  type        = string
  description = "ServiceAccount name for the scoped example workload identity."
}
variable "irsa_policy_arns" {
  type        = set(string)
  description = "Reviewed managed policy ARNs for that workload only."
  default     = []
}
