terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration should be added before production use
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "eks/staging/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "staging"
      Team        = "platform"
      ManagedBy   = "Terraform"
      Project     = "eks-staging"
    }
  }
}

module "eks" {
  source = "../modules/eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_cidr           = var.vpc_cidr

  node_instance_type = var.node_instance_type
  desired_capacity   = var.desired_capacity
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity

  tags = {
    Environment = "staging"
    Purpose     = "application-hosting"
  }
}
