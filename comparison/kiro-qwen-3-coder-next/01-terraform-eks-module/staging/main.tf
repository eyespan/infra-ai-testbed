# Staging environment EKS cluster
# This is an example root module that uses the EKS module

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
  }

  # Remote state configuration - update for your backend
  # terraform {
  #   backend "s3" {
  #     bucket         = "my-terraform-state-bucket"
  #     key            = "staging/eks/terraform.tfstate"
  #     region         = "us-east-1"
  #     encrypt        = true
  #     dynamodb_table = "my-terraform-locks"
  #   }
  # }
}

# Configure AWS provider (use environment variable AWS_REGION or default to us-east-1)
provider "aws" {
  region = var.region
}

# EKS module
module "eks" {
  source = "../modules/eks"

  # Required variables
  cluster_name  = "staging"
  region        = var.region
  vpc_cidr      = "10.100.0.0/16"

  # Kubernetes configuration
  kubernetes_version = "1.29"

  # Node group configuration
  node_instance_type = var.node_instance_type
  desired_capacity   = var.desired_capacity
  min_size           = var.min_size
  max_size           = var.max_size

  # Logging and encryption
  cluster_logging_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  log_retention_days    = 30
  enable_cluster_encryption = true

  # Environment tagging
  environment = "staging"
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# Example: Deploy a sample application
# resource "kubernetes_namespace" "example" {
#   metadata {
#     name = "example"
#   }
# }
