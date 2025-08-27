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

# Certificate request from Vault via cert-manager
resource "kubernetes_manifest" "demo_certificate" {
  count = var.install_vault_integration ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "nginx-demo-tls"
      namespace = "demo"
    }
    spec = {
      secretName  = "nginx-demo-tls"
      commonName  = "nginx-demo.${local.domain_name}"
      dnsNames = [
        "nginx-demo.${local.domain_name}",
        "nginx-demo.demo.svc.cluster.local"
      ]
      duration    = "24h"
      renewBefore = "8h"
      privateKey = {
        algorithm      = "RSA"
        size           = 2048
        rotationPolicy = "Always"
      }
      issuerRef = {
        name  = "vault-issuer"
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
      usages = [
        "digital signature",
        "key encipherment",
        "server auth",
        "client auth"
      ]
    }
  }

  depends_on = [
    kubernetes_namespace.demo,
    kubernetes_manifest.vault_cluster_issuer
  ]
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
          listen 443 ssl;
          
          server_name nginx-demo.${local.domain_name};
          
          ssl_certificate /etc/nginx/certs/tls.crt;
          ssl_certificate_key /etc/nginx/certs/tls.key;
          
          ssl_protocols TLSv1.2 TLSv1.3;
          ssl_ciphers HIGH:!aNULL:!MD5;
          
          location / {
              root   /usr/share/nginx/html;
              index  index.html index.htm;
              add_header X-Certificate-Source "HashiCorp Vault via cert-manager" always;
              add_header X-Certificate-Issuer "vault-issuer" always;
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

# NGINX Demo Deployment
resource "kubernetes_deployment" "nginx_demo" {
  count = var.install_vault_integration ? 1 : 0

  metadata {
    name      = "nginx-demo"
    namespace = "demo"
    labels = {
      app = "nginx-demo"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "nginx-demo"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-demo"
        }
      }

      spec {
        container {
          image = "nginx:alpine"
          name  = "nginx"

          port {
            container_port = 80
            name           = "http"
          }

          port {
            container_port = 443
            name           = "https"
          }

          volume_mount {
            name       = "tls-certs"
            mount_path = "/etc/nginx/certs"
            read_only  = true
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d"
            read_only  = true
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "200m"
            }
          }
        }

        volume {
          name = "tls-certs"
          secret {
            secret_name = "nginx-demo-tls"
          }
        }

        volume {
          name = "nginx-config"
          config_map {
            name = "nginx-config"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.demo,
    kubernetes_manifest.demo_certificate,
    kubernetes_config_map.nginx_config
  ]
}

# Service for demo application (LoadBalancer for direct access)
resource "kubernetes_service" "nginx_demo" {
  count = var.install_vault_integration ? 1 : 0

  metadata {
    name      = "nginx-demo"
    namespace = "demo"
    labels = {
      app = "nginx-demo"
    }
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "nginx-demo"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    port {
      name        = "https"
      port        = 443
      target_port = 443
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.nginx_demo]
}