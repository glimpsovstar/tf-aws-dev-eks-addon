# Get the NGINX LoadBalancer hostname after deployment
data "kubernetes_service" "nginx_ingress_controller" {
  count = var.install_nginx_ingress ? 1 : 0

  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  
  depends_on = [helm_release.nginx_ingress, time_sleep.wait_for_nginx]
}

output "ingress_load_balancer_hostname" {
  description = "NGINX Ingress LoadBalancer hostname"
  value       = var.install_nginx_ingress ? try(data.kubernetes_service.nginx_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname, "pending") : null
}

output "ingress_load_balancer_ip" {
  description = "NGINX Ingress LoadBalancer IP (if available)"
  value       = var.install_nginx_ingress ? try(data.kubernetes_service.nginx_ingress_controller[0].status[0].load_balancer[0].ingress[0].ip, null) : null
}

# SSL Infrastructure outputs
output "nginx_ingress_controller_installed" {
  description = "Whether NGINX ingress controller is installed"
  value       = var.install_nginx_ingress
}

output "cert_manager_installed" {
  description = "Whether cert-manager is installed"
  value       = var.install_cert_manager
}

output "letsencrypt_cluster_issuer_prod" {
  description = "Name of the production Let's Encrypt ClusterIssuer (create manually)"
  value       = var.install_cert_manager && var.letsencrypt_email != "" ? "letsencrypt-prod" : null
}

output "letsencrypt_cluster_issuer_staging" {
  description = "Name of the staging Let's Encrypt ClusterIssuer (create manually)"
  value       = var.install_cert_manager && var.letsencrypt_email != "" ? "letsencrypt-staging" : null
}

output "cluster_issuers_instructions" {
  description = "Instructions for creating ClusterIssuers manually"
  value = var.install_cert_manager && var.letsencrypt_email != "" ? <<EOT

To create the Let's Encrypt ClusterIssuers, run these commands:

1. Configure kubectl:
   aws eks update-kubeconfig --region ${var.aws_region} --name ${data.terraform_remote_state.eks_foundation.outputs.eks_cluster_name}

2. Verify cert-manager is running:
   kubectl get pods -n cert-manager

3. Apply the ClusterIssuers:
   kubectl apply -f cluster-issuers.yaml

4. Verify ClusterIssuers are created:
   kubectl get clusterissuers

The cluster-issuers.yaml file has been generated in your current directory.

EOT
 : "cert-manager not installed"
}

# Information from foundation workspace
output "eks_cluster_name" {
  description = "EKS cluster name from foundation"
  value       = data.terraform_remote_state.eks_foundation.outputs.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint from foundation"
  value       = data.terraform_remote_state.eks_foundation.outputs.eks_cluster_endpoint
}