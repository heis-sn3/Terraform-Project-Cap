variable "prefix" {
  type        = string
  description = "Project prefix for resource naming"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, qa, prod)"

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod"
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region for resources"
}

variable "app_name" {
  type        = string
  description = "Application name for tagging"
}

variable "owner" {
  type        = string
  description = "Owner/team name for tagging"
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

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT"
  }
}

variable "node_min" {
  type        = number
  description = "Minimum number of nodes"

  validation {
    condition     = var.node_min >= 1
    error_message = "node_min must be at least 1"
  }
}

variable "node_max" {
  type        = number
  description = "Maximum number of nodes"

  validation {
    condition     = var.node_max >= 1
    error_message = "node_max must be at least 1"
  }
}

variable "node_desired" {
  type        = number
  description = "Desired number of nodes"

  validation {
    condition     = var.node_desired >= 1
    error_message = "node_desired must be at least 1"
  }
}

variable "nodeport_from" {
  type        = number
  description = "NodePort range start for ingress rules"
  default     = 30007
}

variable "nodeport_to" {
  type        = number
  description = "NodePort range end for ingress rules"
  default     = 30007
}
