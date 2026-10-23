# Reference the default VPC and existing subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "selected" {
  for_each   = toset(var.subnet_cidrs)
  vpc_id     = data.aws_vpc.default.id
  cidr_block = each.value
}

locals {
  subnet_ids = [for s in data.aws_subnet.selected : s.id]
}

resource "aws_eks_cluster" "example" {
  name = local.eks_cluster_name

  access_config {
    authentication_mode = "API"
    #bootstrap_cluster_creator_admin_permissions = true
  }

  role_arn = aws_iam_role.cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids = local.subnet_ids
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
}

resource "aws_iam_role" "cluster" {
  name = local.iam_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# authentication_mode = "API" means Kubernetes RBAC access is governed
# entirely by EKS access entries, not IAM policies or aws-auth. Without
# this, the IAM principal that creates/manages the cluster has no way
# to authenticate to the Kubernetes API.
data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.example.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.example.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_iam_role" "node" {
  name = local.node_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource "aws_vpc_security_group_ingress_rule" "nodeport" {
  security_group_id = aws_eks_cluster.example.vpc_config[0].cluster_security_group_id
  description       = "Allow inbound access to nginx NodePort service"
  from_port         = var.nodeport_from
  to_port           = var.nodeport_to
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# Launch template for the worker nodes. Its only job is to force a public IP
# onto each node's primary ENI so nodes are directly reachable (NodePort demo).
# We deliberately omit image_id/instance_type/user_data so EKS still injects the
# EKS-optimized AMI, bootstrap script, and (via the node group) SPOT instance
# types. Because specifying network_interfaces overrides the default ENI, we must
# attach the cluster security group here — it carries the :30007 ingress rule.
resource "aws_launch_template" "node" {
  name_prefix = "${local.node_group_name}-"
  description = "EKS worker nodes with public IPs on launch"

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_eks_cluster.example.vpc_config[0].cluster_security_group_id]
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = local.node_group_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = local.subnet_ids

  capacity_type  = var.capacity_type
  instance_types = var.instance_types

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    min_size     = var.node_min
    max_size     = var.node_max
    desired_size = var.node_desired
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure IAM permissions are created before and deleted after the
  # node group, otherwise EKS cannot properly bootstrap/tear down nodes.
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}
