# Data source to get EKS cluster info from the foundation workspace
data "terraform_remote_state" "eks_foundation" {
  backend = "remote"
  config = {
    organization = "djoo-hashicorp"
    workspaces = {
      name = "tf-aws-dev-eks"  # Foundation workspace
    }
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Local values for common configuration
locals {
  route53_zone_id = data.terraform_remote_state.eks_foundation.outputs.route53_zone_id
  domain_name     = data.terraform_remote_state.eks_foundation.outputs.route53_zone_name
  eks_cluster_name = data.terraform_remote_state.eks_foundation.outputs.eks_cluster_name
  
  # Use base_domain if provided, otherwise fall back to foundation domain
  effective_base_domain = var.base_domain != "" ? var.base_domain : local.domain_name
  
  # Handle app_names variable - support both set and string formats from TFC
  effective_app_names = try(
    var.app_names,  # If it's already a set, use it
    toset(jsondecode(var.app_names)),  # If it's a JSON string, parse it
    toset([])  # Fallback to empty set
  )
}