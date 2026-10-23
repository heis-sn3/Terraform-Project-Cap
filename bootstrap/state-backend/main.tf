terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
  # No backend block - uses local state
}

provider "aws" {
  region = var.aws_region
}

module "state" {
  source   = "../../modules/capitec_s3"
  for_each = toset(var.environments)

  prefix            = var.prefix
  environment       = each.key
  enable_versioning = true
  force_destroy     = false
}
