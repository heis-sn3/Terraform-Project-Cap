variable "prefix" {
  type        = string
  description = "Project prefix for resource naming"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, qa, prod)"
}

variable "rsrc" {
  type        = string
  description = "Resource type identifier"
}

variable "eks_version" {
  type        = string
  description = "Kubernetes version for EKS cluster"
}

variable "subnet_cidrs" {
  type        = list(string)
  description = "List of subnet CIDR blocks"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types for node group"
}

variable "capacity_type" {
  type        = string
  description = "Node capacity type (ON_DEMAND or SPOT)"
}

variable "node_min" {
  type        = number
  description = "Minimum number of nodes"
}

variable "node_max" {
  type        = number
  description = "Maximum number of nodes"
}

variable "node_desired" {
  type        = number
  description = "Desired number of nodes"
}

variable "nodeport_from" {
  type        = number
  description = "NodePort range start for ingress rules"
}

variable "nodeport_to" {
  type        = number
  description = "NodePort range end for ingress rules"
}

locals {
  eks_cluster_name = "${var.prefix}-${var.rsrc}-${var.environment}"
  iam_role_name    = "${var.prefix}-${var.rsrc}-iam-role-${var.environment}"
  node_group_name  = "${var.prefix}-${var.rsrc}-nodes-${var.environment}"
  node_role_name   = "${var.prefix}-${var.rsrc}-node-role-${var.environment}"
}