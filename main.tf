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

# Local values for common configuration
locals {
  route53_zone_id = data.terraform_remote_state.eks_foundation.outputs.route53_zone_id
  domain_name     = data.terraform_remote_state.eks_foundation.outputs.route53_zone_name
  eks_cluster_name = data.terraform_remote_state.eks_foundation.outputs.eks_cluster_name
}