# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.cluster_name}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.cluster_name}-igw"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Public subnets (one per AZ)
resource "aws_subnet" "public" {
  count = 3

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.cluster_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "terraform"
    # Kubernetes ELB discovery tags
    "kubernetes.io/role/elb" = "1"
  }
}

# Private subnets (one per AZ)
resource "aws_subnet" "private" {
  count = 3

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.cluster_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "terraform"
    # Kubernetes internal ELB discovery tags
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# NAT Gateway (one per public subnet)
resource "aws_eip" "nat" {
  count = 3

  domain = "vpc"

  tags = {
    Name        = "${var.cluster_name}-nat-eip-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_nat_gateway" "this" {
  count = 3

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.cluster_name}-nat-gw-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_internet_gateway.this]
}

# Route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "${var.cluster_name}-public-rt"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table" "private" {
  count = 3

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = {
    Name        = "${var.cluster_name}-private-rt-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Route table associations
resource "aws_route_table_association" "public" {
  count = 3

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = 3

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security group for EKS cluster
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.cluster_name}-cluster-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Security group rules for cluster to node communication
resource "aws_security_group_rule" "cluster_to_nodes" {
  description       = "Allow cluster to communicate with nodes"
  security_group_id = aws_security_group.nodes.id
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  type              = "ingress"
  cidr_blocks       = [aws_vpc.this.cidr_block]
}

resource "aws_security_group_rule" "nodes_to_cluster" {
  description       = "Allow nodes to communicate with cluster"
  security_group_id = aws_security_group.cluster.id
  protocol          = "tcp"
  from_port         = 1024
  to_port           = 65535
  type              = "ingress"
  cidr_blocks       = [aws_vpc.this.cidr_block]
}

# Security group for nodes
resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow inbound traffic from cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.cluster_name}-node-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch log group for EKS
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.cluster_name}-cluster-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# KMS key for cluster encryption (if enabled)
resource "aws_kms_key" "cluster" {
  count = var.enable_cluster_encryption ? 1 : 0

  description         = "KMS key for EKS cluster encryption"
  deletion_window_in_days = 30
  enable_key_rotation   = true

  tags = {
    Name        = "${var.cluster_name}-cluster-encryption-key"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "cluster" {
  count = var.enable_cluster_encryption ? 1 : 0

  name          = "alias/${var.cluster_name}-cluster-encryption"
  target_key_id = aws_kms_key.cluster[0].key_id
}

# EKS cluster
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]

    security_group_ids = [
      aws_security_group.cluster.id,
    ]

    subnet_ids = aws_subnet.private[*].id
  }

  # Cluster encryption
  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = var.enable_cluster_encryption ? aws_kms_key.cluster[0].arn : null
    }
  }

  # Cluster logging
  enabled_cluster_log_types = var.cluster_logging_types

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_service_policy,
    aws_cloudwatch_log_group.cluster,
  ]
}

# EKS managed node group
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.nodes.arn
  version         = var.kubernetes_version

  instance_types = [var.node_instance_type]

  subnet_ids = aws_subnet.private[*].id

  scaling_config {
    desired_size = var.desired_capacity
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    instance-type = var.node_instance_type
  }

  tags = {
    Name        = "${var.cluster_name}-node-group"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.node_additional_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_registry_policy,
    aws_security_group_rule.cluster_to_nodes,
  ]

  # Wait for cluster to be ready
  lifecycle {
    create_before_destroy = true
  }
}
