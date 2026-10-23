# Root re-exports the eks module outputs so each environment's state publishes
# them. Other stacks consume these via a terraform_remote_state data source
# pointed at envs/<env>/<env>.tfbackend.

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = module.eks.cluster_iam_role_arn
}

output "node_iam_role_arn" {
  description = "ARN of the worker node IAM role"
  value       = module.eks.node_iam_role_arn
}

output "node_group_arn" {
  description = "ARN of the managed node group"
  value       = module.eks.node_group_arn
}

output "launch_template_arn" {
  description = "ARN of the worker node launch template"
  value       = module.eks.launch_template_arn
}
