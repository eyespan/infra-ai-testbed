terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Configure an encrypted, locked remote backend per environment before apply.
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

module "eks" {
  source = "../modules/eks"

  cluster_name              = var.cluster_name
  kubernetes_version        = var.kubernetes_version
  node_instance_type        = var.node_instance_type
  desired_capacity          = var.desired_capacity
  min_capacity              = var.min_capacity
  max_capacity              = var.max_capacity
  vpc_cidr                  = var.vpc_cidr
  cloudwatch_log_kms_key_id = var.cloudwatch_log_kms_key_id
  secrets_kms_key_arn       = var.secrets_kms_key_arn
  irsa_namespace            = var.irsa_namespace
  irsa_service_account_name = var.irsa_service_account_name
  irsa_policy_arns          = var.irsa_policy_arns

  tags = {
    Environment = var.environment
  }
}
