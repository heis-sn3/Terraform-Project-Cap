# Exposed so other modules / remote-state consumers can wire into the cluster.
# ARNs for every resource that another stack might reference, plus the cluster
# name/endpoint that those ARNs are meaningless without.

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.example.arn
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.example.name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = aws_eks_cluster.example.endpoint
}

output "cluster_security_group_id" {
  description = "Cluster security group ID (carries the NodePort ingress rule)"
  value       = aws_eks_cluster.example.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "ARN of the worker node IAM role"
  value       = aws_iam_role.node.arn
}

output "node_group_arn" {
  description = "ARN of the managed node group"
  value       = aws_eks_node_group.main.arn
}

output "launch_template_arn" {
  description = "ARN of the worker node launch template"
  value       = aws_launch_template.node.arn
}
