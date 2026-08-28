variable "cluster_name" {
  type        = string
  description = "Unique EKS cluster name."
  validation {
    condition     = can(regex("^[0-9A-Za-z][0-9A-Za-z_-]{0,99}$", var.cluster_name))
    error_message = "cluster_name must be 1-100 characters using letters, numbers, underscores, or hyphens."
  }
}

variable "kubernetes_version" {
  type        = string
  description = "An EKS-supported Kubernetes version, selected by the caller."
}

variable "node_instance_type" {
  type        = string
  description = "Instance type for the managed node group."
  default     = "t3.medium"
}

variable "desired_capacity" {
  type        = number
  description = "Requested node count; zero is permitted only when min_capacity is also zero."
  default     = 3
  validation {
    condition     = var.desired_capacity >= 0 && floor(var.desired_capacity) == var.desired_capacity
    error_message = "desired_capacity must be a non-negative whole number."
  }
}

variable "min_capacity" {
  type        = number
  description = "Minimum node count."
  default     = 1
  validation {
    condition     = var.min_capacity >= 0 && floor(var.min_capacity) == var.min_capacity
    error_message = "min_capacity must be a non-negative whole number."
  }
}

variable "max_capacity" {
  type        = number
  description = "Maximum node count."
  default     = 5
  validation {
    condition     = var.max_capacity >= 0 && floor(var.max_capacity) == var.max_capacity
    error_message = "max_capacity must be a non-negative whole number."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR with room for six /20-or-smaller subnets."
  validation {
    condition     = can(cidrsubnet(var.vpc_cidr, 4, 15))
    error_message = "vpc_cidr must be a valid CIDR with room to allocate six subnets."
  }
}

variable "cloudwatch_log_kms_key_id" {
  type        = string
  description = "Customer-managed KMS key ARN or ID used by the CloudWatch EKS log group."
}

variable "secrets_kms_key_arn" {
  type        = string
  description = "Customer-managed KMS key ARN used for EKS Kubernetes Secret envelope encryption."
}

variable "irsa_namespace" {
  type        = string
  description = "Namespace allowed to assume the example IRSA workload role."
}

variable "irsa_service_account_name" {
  type        = string
  description = "ServiceAccount allowed to assume the example IRSA workload role."
}

variable "irsa_policy_arns" {
  type        = set(string)
  description = "Reviewed, workload-specific managed policy ARNs for the example IRSA role."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to supported resources."
  default     = {}
}
