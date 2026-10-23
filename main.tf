module "eks" {
  source = "./modules/capitec_eks"

  # Naming
  prefix      = var.prefix
  environment = var.environment
  rsrc        = var.rsrc

  # EKS Configuration
  eks_version  = var.eks_version
  subnet_cidrs = var.subnet_cidrs

  # Node Group Configuration
  instance_types = var.instance_types
  capacity_type  = var.capacity_type
  node_min       = var.node_min
  node_max       = var.node_max
  node_desired   = var.node_desired

  # Security Configuration
  nodeport_from = var.nodeport_from
  nodeport_to   = var.nodeport_to
}




