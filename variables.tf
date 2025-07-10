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

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}