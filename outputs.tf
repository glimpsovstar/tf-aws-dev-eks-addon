# Outputs for EKS Add-ons Workspace
# Note: Data sources and resources are defined in their respective directories

# Infrastructure outputs
output "nginx_ingress_controller_installed" {
  description = "Whether NGINX ingress controller is installed"
  value       = var.install_nginx_ingress
}

output "cert_manager_installed" {
  description = "Whether cert-manager is installed"
  value       = var.install_cert_manager
}

output "vault_integration_enabled" {
  description = "Whether Vault PKI integration is enabled"
  value       = var.install_vault_integration
}

output "storage_classes_created" {
  description = "Whether additional storage classes are created"
  value       = var.create_storage_classes
}

# Foundation workspace information
output "eks_cluster_name" {
  description = "EKS cluster name from foundation workspace"
  value       = local.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint from foundation workspace"
  value       = data.terraform_remote_state.eks_foundation.outputs.eks_cluster_endpoint
}

output "route53_zone_name" {
  description = "Route53 zone name from foundation workspace"
  value       = local.domain_name
}

# DNS outputs
output "dns_records_created" {
  description = "DNS records created pointing to LoadBalancer"
  value       = var.app_dns_records
}

output "wildcard_dns_created" {
  description = "Wildcard DNS record created"
  value       = var.create_wildcard_dns ? var.wildcard_domain : null
}

# Certificate management outputs
output "letsencrypt_cluster_issuer_prod" {
  description = "Name of the production Let's Encrypt ClusterIssuer"
  value       = var.create_letsencrypt_issuers && var.letsencrypt_email != "" ? "letsencrypt-prod" : null
}

output "letsencrypt_cluster_issuer_staging" {
  description = "Name of the staging Let's Encrypt ClusterIssuer"
  value       = var.create_letsencrypt_issuers && var.letsencrypt_email != "" ? "letsencrypt-staging" : null
}

output "vault_cluster_issuer" {
  description = "Name of the Vault ClusterIssuer (Phase 3)"
  value       = var.install_vault_integration ? "vault-issuer" : null
}

# Instructions for manual steps
output "kubectl_config_command" {
  description = "Command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${local.eks_cluster_name}"
}

output "cluster_issuers_instructions" {
  description = "Instructions for verifying ClusterIssuers"
  value       = "After deployment, verify with: kubectl get clusterissuer"
}