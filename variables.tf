variable "aws_region" {
  description = "AWS region where the EKS cluster is deployed"
  type        = string
  default     = "ap-southeast-2"
}

# SSL Configuration
variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt notifications"
  type        = string
  default     = ""
}

variable "install_nginx_ingress" {
  description = "Whether to install NGINX ingress controller"
  type        = bool
  default     = true
}

variable "install_cert_manager" {
  description = "Whether to install cert-manager for SSL"
  type        = bool
  default     = true
}

# DNS Configuration for LoadBalancer-dependent records
variable "base_domain" {
  description = "Base domain for creating app DNS records"
  type        = string
  default     = ""
  # Example: "david-joo.sbx.hashidemos.io"
}

variable "app_names" {
  description = "List of app names to create DNS records for (will be prefixed to base_domain)"
  type        = list(string)
  default     = []
  # Example: ["nginx-demo", "vault", "api"] creates nginx-demo.domain.com, vault.domain.com, etc.
}

variable "app_dns_records" {
  description = "Full DNS records to create pointing to LoadBalancer (legacy - use app_names + base_domain instead)"
  type        = set(string)
  default     = []
  # Example: ["vault.yourdomain.com", "api.yourdomain.com"]
}

variable "create_wildcard_dns" {
  description = "Whether to create wildcard DNS record"
  type        = bool
  default     = false
}

variable "wildcard_domain" {
  description = "Wildcard domain to create (e.g., '*.yourdomain.com')"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Certificate management variables
variable "create_letsencrypt_issuers" {
  description = "Whether to create Let's Encrypt ClusterIssuers"
  type        = bool
  default     = false
}

# Vault integration variables (Phase 3)
variable "install_vault_integration" {
  description = "Whether to install Vault PKI integration"
  type        = bool
  default     = false
}

variable "demo_app_name" {
  description = "Name of the demo app for DNS and certificate"
  type        = string
  default     = "nginx-demo"
}

variable "manage_existing_resources" {
  description = "Whether to manage existing resources that were created manually (set to false to avoid conflicts)"
  type        = bool
  default     = false
}

# Storage configuration
variable "create_storage_classes" {
  description = "Whether to create additional storage classes"
  type        = bool
  default     = true
}