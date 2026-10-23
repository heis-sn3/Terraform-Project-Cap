variable "prefix" {
  type        = string
  description = "distinguishing prefix for resource arguments which identifies the owner"
}

variable "environment" {
  type        = string
  description = "Name of the environment (dev, qa, prod)"
}

variable "enable_versioning" {
  type        = bool
  description = "Whether to enable versioning for the S3 bucket"
  default     = true
}

variable "force_destroy" {
  type        = bool
  description = "Allow bucket to be destroyed even if it contains objects"
  default     = false
}
