# Horizontal Pod Autoscaler (HPA) Configuration
# Automatically scales pods based on CPU/memory usage

# Install Metrics Server for HPA to work
resource "helm_release" "metrics_server" {
  count = var.install_cluster_autoscaler ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.1"
  namespace  = "kube-system"

  values = [
    yamlencode({
      args = [
        "--cert-dir=/tmp",
        "--secure-port=4443",
        "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
        "--kubelet-use-node-status-port",
        "--metric-resolution=15s"
      ]
      
      resources = {
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "500Mi"
        }
      }
    })
  ]
}

# HPA for nginx-demo app
resource "kubernetes_horizontal_pod_autoscaler_v2" "nginx_demo_hpa" {
  count = var.install_vault_integration && var.install_cluster_autoscaler ? 1 : 0

  metadata {
    name      = "${var.demo_app_name}-hpa"
    namespace = "demo"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = var.demo_app_name
    }

    min_replicas = 2
    max_replicas = 10

    # Scale based on CPU usage
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70  # Scale up when CPU > 70%
        }
      }
    }

    # Scale based on Memory usage  
    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80  # Scale up when Memory > 80%
        }
      }
    }

    # Scaling behavior configuration
    behavior {
      scale_up {
        stabilization_window_seconds = 60  # Wait 1 minute before scaling up again
        select_policy               = "Max"
        policy {
          type          = "Percent"
          value         = 100  # Scale up by 100% (double pods)
          period_seconds = 60
        }
        policy {
          type          = "Pods"
          value         = 2    # Or add 2 pods maximum
          period_seconds = 60
        }
      }
      
      scale_down {
        stabilization_window_seconds = 300  # Wait 5 minutes before scaling down
        select_policy               = "Min"
        policy {
          type          = "Percent"
          value         = 50   # Scale down by 50% maximum
          period_seconds = 60
        }
        policy {
          type          = "Pods"  
          value         = 1    # Or remove 1 pod maximum
          period_seconds = 60
        }
      }
    }
  }

  depends_on = [
    helm_release.metrics_server,
    kubernetes_deployment.nginx_demo
  ]
}

# Vertical Pod Autoscaler (VPA) - Optional recommendation engine
resource "kubernetes_manifest" "nginx_demo_vpa" {
  count = var.install_vault_integration && var.install_cluster_autoscaler ? 1 : 0

  manifest = {
    apiVersion = "autoscaling.k8s.io/v1"
    kind       = "VerticalPodAutoscaler"
    metadata = {
      name      = "${var.demo_app_name}-vpa"
      namespace = "demo"
    }
    spec = {
      targetRef = {
        apiVersion = "apps/v1"
        kind       = "Deployment"
        name       = var.demo_app_name
      }
      updatePolicy = {
        updateMode = "Off"  # Recommendation only, don't auto-update
      }
      resourcePolicy = {
        containerPolicies = [
          {
            containerName = "nginx"
            minAllowed = {
              cpu    = "50m"
              memory = "32Mi"
            }
            maxAllowed = {
              cpu    = "500m"
              memory = "256Mi"
            }
            controlledResources = ["cpu", "memory"]
          }
        ]
      }
    }
  }

  depends_on = [kubernetes_deployment.nginx_demo]
}

# Output HPA information
output "hpa_status" {
  description = "HPA configuration status"
  value = var.install_vault_integration && var.install_cluster_autoscaler ? {
    name         = kubernetes_horizontal_pod_autoscaler_v2.nginx_demo_hpa[0].metadata[0].name
    namespace    = kubernetes_horizontal_pod_autoscaler_v2.nginx_demo_hpa[0].metadata[0].namespace
    min_replicas = kubernetes_horizontal_pod_autoscaler_v2.nginx_demo_hpa[0].spec[0].min_replicas
    max_replicas = kubernetes_horizontal_pod_autoscaler_v2.nginx_demo_hpa[0].spec[0].max_replicas
  } : null
}