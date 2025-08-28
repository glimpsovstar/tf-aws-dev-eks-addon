# Data source to get EKS cluster info from the foundation workspace
data "terraform_remote_state" "eks_foundation" {
  backend = "remote"
  config = {
    organization = "djoo-hashicorp"
    workspaces = {
      name = "tf-aws-dev-eks" # Foundation workspace
    }
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Local values for common configuration
locals {
  route53_zone_id  = data.terraform_remote_state.eks_foundation.outputs.route53_zone_id
  domain_name      = data.terraform_remote_state.eks_foundation.outputs.route53_zone_name
  eks_cluster_name = data.terraform_remote_state.eks_foundation.outputs.eks_cluster_name

  # Use base_domain if provided, otherwise fall back to foundation domain
  effective_base_domain = var.base_domain != "" ? var.base_domain : local.domain_name

  # Convert app_names list to set for for_each usage
  # Exclude nginx-demo from app_names as it has its own dedicated DNS record
  effective_app_names = toset([for app in var.app_names : app if app != "nginx-demo"])
}