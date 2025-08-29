# Phase 3 Demo Application
# NGINX app with Vault-issued certificates via cert-manager

# Demo namespace
resource "kubernetes_namespace" "demo" {
  count = var.install_vault_integration ? 1 : 0

  metadata {
    name = "demo"
    labels = {
      name = "demo"
    }
  }
}

# Note: Certificate is now automatically created by the Ingress annotation
# cert-manager.io/cluster-issuer: "vault-issuer"

# HTML content for SSL monitoring website
resource "kubernetes_config_map" "nginx_html" {
  count = var.install_vault_integration && var.manage_existing_resources ? 1 : 0

  metadata {
    name      = "nginx-html"
    namespace = "demo"
  }

  data = {
    "index.html" = file("${path.module}/ssl-monitor.html")
  }

  depends_on = [kubernetes_namespace.demo]
}

# NGINX Configuration with TLS
resource "kubernetes_config_map" "nginx_config" {
  count = var.install_vault_integration ? 1 : 0

  metadata {
    name      = "nginx-config"
    namespace = "demo"
  }

  data = {
    "default.conf" = <<-EOT
      server {
          listen 80;
          
          server_name ${var.demo_app_name}.${local.effective_base_domain};
          
          location / {
              root   /usr/share/nginx/html;
              index  index.html index.htm;
              add_header X-Certificate-Source "HashiCorp Vault via cert-manager" always;
              add_header X-Certificate-Issuer "vault-issuer" always;
          }
          
          location /api/cert-info {
              add_header Content-Type "application/json" always;
              return 200 '{
                  "certificate": {
                      "source": "HashiCorp Vault via cert-manager",
                      "issuer": "vault-issuer",
                      "note": "Certificate details available via Ingress termination"
                  },
                  "server": {
                      "hostname": "$hostname",
                      "timestamp": "$time_iso8601"
                  }
              }';
          }
          
          location /api/renew-cert {
              if ($request_method != POST) {
                  add_header Content-Type "application/json" always;
                  return 405 '{"error": "Method not allowed. Use POST."}';
              }
              # Simple renewal endpoint - returns success for demo
              add_header Content-Type "application/json" always;
              return 200 '{"message": "Certificate renewal triggered", "status": "success"}';
          }
          
          location /health {
              access_log off;
              return 200 "healthy\\n";
              add_header Content-Type text/plain;
          }
      }
    EOT
  }

  depends_on = [kubernetes_namespace.demo]
}

# NGINX Demo Deployment with automatic certificate rotation
resource "kubernetes_deployment" "nginx_demo" {
  count = var.install_vault_integration ? 1 : 0

  metadata {
    name      = var.demo_app_name
    namespace = "demo"
    labels = {
      app     = var.demo_app_name
      tier    = "frontend"
      purpose = "vault-demo"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = var.demo_app_name
      }
    }

    template {
      metadata {
        labels = {
          app     = var.demo_app_name
          tier    = "frontend"
          purpose = "vault-demo"
        }
        annotations = {
          "cert-manager.io/issuer" = "vault-issuer"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"

          port {
            container_port = 80
            name           = "http"
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d"
          }
          
          volume_mount {
            name       = "nginx-html"
            mount_path = "/usr/share/nginx/html"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "nginx-config"
          config_map {
            name = kubernetes_config_map.nginx_config[0].metadata[0].name
          }
        }
        
        volume {
          name = "nginx-html"
          config_map {
            name = kubernetes_config_map.nginx_html[0].metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.demo,
    kubernetes_config_map.nginx_config,
    kubernetes_config_map.nginx_html
  ]
}

# Service for demo application (ClusterIP for Ingress access)
resource "kubernetes_service" "nginx_demo" {
  count = var.install_vault_integration ? 1 : 0

  metadata {
    name      = var.demo_app_name
    namespace = "demo"
    labels = {
      app = var.demo_app_name
    }
  }

  spec {
    selector = {
      app = var.demo_app_name
    }
    
    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    
    type = "ClusterIP"
  }

  depends_on = [
    kubernetes_deployment.nginx_demo
  ]
}

# Ingress for demo application
resource "kubernetes_ingress_v1" "nginx_demo" {
  count = var.install_vault_integration ? 1 : 0

  metadata {
    name      = var.demo_app_name
    namespace = "demo"
    annotations = {
      "kubernetes.io/ingress.class"                    = "nginx"
      "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
      "cert-manager.io/cluster-issuer"                 = "vault-issuer"
      "cert-manager.io/common-name"                    = "${var.demo_app_name}.${local.effective_base_domain}"
    }
  }

  spec {
    tls {
      hosts = ["${var.demo_app_name}.${local.effective_base_domain}"]
      secret_name = "${var.demo_app_name}-ingress-tls"
    }

    rule {
      host = "${var.demo_app_name}.${local.effective_base_domain}"
      
      http {
        path {
          path = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = kubernetes_service.nginx_demo[0].metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service.nginx_demo
  ]
}