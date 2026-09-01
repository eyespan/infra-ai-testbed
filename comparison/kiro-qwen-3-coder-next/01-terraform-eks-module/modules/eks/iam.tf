# Cluster IAM role
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-cluster-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Cluster policy attachment
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# Node group IAM role
resource "aws_iam_role" "nodes" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-node-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  count = length(aws_iam_policy.node_policy)
  policy_arn = aws_iam_policy.node_policy[count.index].arn
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "node_additional_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "node_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role       = aws_iam_role.nodes.name
}

# Node instance profile
resource "aws_iam_instance_profile" "nodes" {
  name = "${var.cluster_name}-node-instance-profile"
  role = aws_iam_role.nodes.name
}

# Custom node policy for additional permissions
resource "aws_iam_policy" "node_policy" {
  count = var.enable_cluster_encryption ? 1 : 0

  name        = "${var.cluster_name}-node-policy"
  description = "Additional policy for EKS nodes with KMS access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn != "" ? var.kms_key_arn : "*"
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-node-policy"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
