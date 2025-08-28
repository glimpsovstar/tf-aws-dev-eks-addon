# Load Generator for Testing Autoscaling
# Creates a deployment that can generate load to test HPA and Cluster Autoscaler

# Load generator deployment for testing autoscaling
resource "kubernetes_deployment" "load_generator" {
  count = var.install_cluster_autoscaler ? 1 : 0

  metadata {
    name      = "load-generator"
    namespace = "demo"
    labels = {
      app = "load-generator"
    }
  }

  spec {
    replicas = 0 # Start with 0 replicas, scale manually when testing

    selector {
      match_labels = {
        app = "load-generator"
      }
    }

    template {
      metadata {
        labels = {
          app = "load-generator"
        }
      }

      spec {
        container {
          image = "busybox:latest"
          name  = "load-generator"

          # Generate CPU load when running
          command = ["/bin/sh"]
          args    = ["-c", "while true; do echo 'Generating load...'; dd if=/dev/zero of=/dev/null bs=1024 count=1024; sleep 1; done"]

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "500m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "1000m"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.demo]
}

# Instructions for testing autoscaling (as output)
output "autoscaling_test_instructions" {
  value = var.install_cluster_autoscaler ? {
    test_hpa                = "kubectl scale deployment load-generator --replicas=5 -n demo && watch 'kubectl get hpa -n demo && echo && kubectl get pods -n demo'"
    test_cluster_autoscaler = "kubectl scale deployment nginx-demo --replicas=20 -n demo && watch 'kubectl get nodes && echo && kubectl get pods -n demo'"
    cleanup                 = "kubectl scale deployment load-generator --replicas=0 -n demo && kubectl scale deployment nginx-demo --replicas=2 -n demo"
  } : null
}