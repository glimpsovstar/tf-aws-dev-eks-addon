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
variable "app_dns_records" {
  description = "DNS records to create pointing to LoadBalancer"
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