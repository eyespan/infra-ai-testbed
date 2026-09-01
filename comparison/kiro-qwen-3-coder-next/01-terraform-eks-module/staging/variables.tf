# Staging environment variables

variable "region" {
  description = "AWS region for the EKS cluster"
  type        = string
  default     = ""
}

variable "node_instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_capacity" {
  description = "Desired number of nodes"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 6
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "staging"
}
