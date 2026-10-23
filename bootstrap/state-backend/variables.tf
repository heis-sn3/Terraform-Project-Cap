# This stack can't read project.conf at the Terraform level, so these are fed
# as -var by scripts/bootstrap-state-buckets.sh via lib.sh's bootstrap_tf_vars().
# No defaults: the single source of truth is project.conf, not a literal here.

variable "prefix" {
  type        = string
  description = "Project prefix for state-bucket naming (from project.conf PREFIX)"
}

variable "aws_region" {
  type        = string
  description = "AWS region for the state buckets (from project.conf AWS_REGION)"
}

variable "environments" {
  type        = list(string)
  description = "Environments to create a state bucket for (from project.conf ENVIRONMENTS)"
}
