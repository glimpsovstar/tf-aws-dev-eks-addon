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

# Install NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  count            = var.install_nginx_ingress ? 1 : 0
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.8.3"
  namespace        = "ingress-nginx"
  create_namespace = true
  timeout          = 1200  # Increased to 20 minutes
  wait             = true   # Changed to true to wait for completion
  wait_for_jobs    = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"  # Changed back to LoadBalancer
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
    value = "true"
  }

  # Health check settings for faster LB provisioning
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-healthcheck-protocol"
    value = "HTTP"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-healthcheck-port"
    value = "10254"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-healthcheck-path"
    value = "/healthz"
  }

  # Reduce resource requirements for faster startup
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "90Mi"
  }

  # Add replica count for faster deployment
  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  # Add node selector to ensure scheduling
  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
}


# Wait for NGINX Ingress to be ready
resource "time_sleep" "wait_for_nginx" {
  count           = var.install_nginx_ingress ? 1 : 0
  depends_on      = [helm_release.nginx_ingress]
  create_duration = "120s"
}

# Install cert-manager (simplified approach)
resource "helm_release" "cert_manager" {
  count            = var.install_cert_manager ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.13.2"
  namespace        = "cert-manager"
  create_namespace = true
  timeout          = 600
  wait             = true
  wait_for_jobs    = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "extraArgs[0]"
    value = "--enable-certificate-owner-ref=true"
  }

  depends_on = [time_sleep.wait_for_nginx]
}

# Wait for cert-manager to be fully ready
resource "time_sleep" "wait_for_cert_manager" {
  count           = var.install_cert_manager ? 1 : 0
  depends_on      = [helm_release.cert_manager]
  create_duration = "120s"
}

# Create DNS records pointing to LoadBalancer
# This workspace CAN reference LoadBalancer since it creates it
resource "aws_route53_record" "app_records" {
  for_each = var.app_dns_records
  
  zone_id = data.terraform_remote_state.eks_foundation.outputs.route53_zone_id
  name    = each.key
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_service.nginx_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname]

  depends_on = [
    helm_release.nginx_ingress,
    data.kubernetes_service.nginx_ingress_controller
  ]
}

# Create wildcard DNS record (optional)
resource "aws_route53_record" "wildcard" {
  count = var.create_wildcard_dns && var.wildcard_domain != "" ? 1 : 0
  
  zone_id = data.terraform_remote_state.eks_foundation.outputs.route53_zone_id
  name    = var.wildcard_domain
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_service.nginx_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname]

  depends_on = [
    helm_release.nginx_ingress,
    data.kubernetes_service.nginx_ingress_controller
  ]
}