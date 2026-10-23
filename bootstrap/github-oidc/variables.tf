variable "github_org" {
  description = "GitHub organisation or username that owns the repo, e.g. \"Geeks4LearningJHB\""
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (no org prefix), e.g. \"CapitecTerraformInfra\""
  type        = string
}

# Fed as -var from lib.sh bootstrap_tf_vars() (project.conf is the source of
# truth). No defaults so a stale owner value can't drift in here.
variable "prefix" {
  description = "Project prefix — state buckets are named <prefix>-s3-<env> (from project.conf PREFIX)"
  type        = string
}

variable "environments" {
  description = "Environments whose state buckets CI needs access to (from project.conf ENVIRONMENTS)"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region (from project.conf AWS_REGION)"
  type        = string
}
