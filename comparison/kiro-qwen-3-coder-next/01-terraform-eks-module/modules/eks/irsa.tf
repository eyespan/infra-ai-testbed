# OIDC provider for IRSA
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.server_certificates[0].thumbprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = {
    Name        = "${var.cluster_name}-oidc-provider"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Get cluster certificate for OIDC thumbprint
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# IAM role for IRSA consumers
resource "aws_iam_role" "irsa" {
  name = "${var.cluster_name}-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-node"
          }
          StringLike = {
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = [
              "system:serviceaccount:kube-system:*",
              "system:serviceaccount:aws-efs-csi-driver:*",
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-irsa-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Default IAM policy for IRSA consumers
resource "aws_iam_policy" "irsa_default" {
  name        = "${var.cluster_name}-irsa-default-policy"
  description = "Default policy for IRSA consumers"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
        ]
        Resource = [
          "arn:aws:s3:::my-app-bucket/*",
          "arn:aws:s3:::my-app-bucket",
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-irsa-default-policy"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "irsa_default" {
  role       = aws_iam_role.irsa.name
  policy_arn = aws_iam_policy.irsa_default.arn
}
