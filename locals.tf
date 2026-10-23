locals {
  tags = {
    APP         = var.app_name
    OWNER       = var.owner
    DEVELOPER   = var.prefix
    ENVIRONMENT = var.environment
    MANAGED_BY  = "terraform"
  }
}
