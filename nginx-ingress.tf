# NGINX Ingress Controller
# Provides ingress capabilities for the EKS cluster

resource "helm_release" "nginx_ingress" {
  count            = var.install_nginx_ingress ? 1 : 0
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.8.3"
  namespace        = "ingress-nginx"
  create_namespace = true
  timeout          = 1200
  wait             = true
  wait_for_jobs    = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
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

# Data source to get the NGINX LoadBalancer hostname after deployment
data "kubernetes_service" "nginx_ingress_controller" {
  count = var.install_nginx_ingress ? 1 : 0

  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  depends_on = [helm_release.nginx_ingress, time_sleep.wait_for_nginx]
}

# Output the LoadBalancer hostname for use by other modules
output "ingress_load_balancer_hostname" {
  description = "NGINX Ingress LoadBalancer hostname"
  value       = var.install_nginx_ingress ? try(data.kubernetes_service.nginx_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname, "pending") : null
}

output "ingress_load_balancer_ip" {
  description = "NGINX Ingress LoadBalancer IP (if available)"
  value       = var.install_nginx_ingress ? try(data.kubernetes_service.nginx_ingress_controller[0].status[0].load_balancer[0].ingress[0].ip, null) : null
}