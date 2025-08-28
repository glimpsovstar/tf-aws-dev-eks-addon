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
      name      = "${var.demo_app_name}-tls"
      namespace = "demo"
    }
    spec = {
      secretName = "${var.demo_app_name}-tls"
      commonName = "${var.demo_app_name}.${local.effective_base_domain}"
      dnsNames = [
        "${var.demo_app_name}.${local.effective_base_domain}",
        "${var.demo_app_name}.demo.svc.cluster.local"
      ]
      duration    = "1h"
      renewBefore = "50m"
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
          listen 443 ssl;
          
          server_name ${var.demo_app_name}.${local.effective_base_domain};
          
          ssl_certificate /etc/nginx/certs/tls.crt;
          ssl_certificate_key /etc/nginx/certs/tls.key;
          
          ssl_protocols TLSv1.2 TLSv1.3;
          ssl_ciphers HIGH:!aNULL:!MD5;
          
          # Force HTTPS redirect
          if ($scheme = http) {
              return 301 https://$server_name$request_uri;
          }
          
          location / {
              root   /usr/share/nginx/html;
              index  index.html index.htm;
              add_header X-Certificate-Source "HashiCorp Vault via cert-manager" always;
              add_header X-Certificate-Issuer "vault-issuer" always;
              add_header X-Cert-Serial "$ssl_client_serial" always;
              add_header X-Cert-Subject "$ssl_client_s_dn" always;
          }
          
          location /api/cert-info {
              add_header Content-Type "application/json" always;
              return 200 '{
                  "certificate": {
                      "subject": "$ssl_client_s_dn",
                      "issuer": "$ssl_client_i_dn",
                      "serial": "$ssl_client_serial",
                      "valid_from": "$ssl_client_v_start",
                      "valid_until": "$ssl_client_v_end",
                      "fingerprint": "$ssl_client_fingerprint"
                  },
                  "server": {
                      "hostname": "$hostname",
                      "timestamp": "$time_iso8601"
                  }
              }';
          }
          
          location /api/renew-cert {
              if ($request_method = POST) {
                  # Proxy to the renewal sidecar service
                  proxy_pass http://127.0.0.1:8080/api/renew-cert;
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_connect_timeout 30s;
                  proxy_send_timeout 30s;
                  proxy_read_timeout 30s;
              }
              if ($request_method != POST) {
                  add_header Content-Type "application/json" always;
                  return 405 '{"error": "Method not allowed. Use POST."}';
              }
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
# Temporarily removed completely to fix Terraform state corruption
# Will be added back once certificates are working
# resource "kubernetes_deployment" "nginx_demo" { ... }

# Service for demo application (LoadBalancer for direct access)
# Temporarily removed completely to fix Terraform state corruption
# Will be added back once certificates are working
# resource "kubernetes_service" "nginx_demo" { ... }