# Certificate Renewal Sidecar
# Provides API endpoint to trigger actual certificate renewal via kubectl

# ServiceAccount for cert renewal operations
resource "kubernetes_service_account" "cert_renewal" {
  count = var.install_vault_integration && var.manage_existing_resources ? 1 : 0

  metadata {
    name      = "cert-renewal"
    namespace = "demo"
  }

  automount_service_account_token = true

}

# ClusterRole for certificate management
resource "kubernetes_cluster_role" "cert_renewal" {
  count = var.install_vault_integration && var.manage_existing_resources ? 1 : 0

  metadata {
    name = "cert-renewal"
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["certificates", "certificaterequests"]
    verbs      = ["get", "list", "patch", "update", "create"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list"]
  }
}

# ClusterRoleBinding
resource "kubernetes_cluster_role_binding" "cert_renewal" {
  count = var.install_vault_integration && var.manage_existing_resources ? 1 : 0

  metadata {
    name = "cert-renewal"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cert_renewal[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cert_renewal[0].metadata[0].name
    namespace = "demo"
  }
}

# ConfigMap with the renewal script
resource "kubernetes_config_map" "cert_renewal_script" {
  count = var.install_vault_integration && var.manage_existing_resources ? 1 : 0

  metadata {
    name      = "cert-renewal-script"
    namespace = "demo"
  }

  lifecycle {
    ignore_changes = []
  }

  data = {
    "renew-cert.sh" = <<-EOT
      #!/bin/bash
      set -e
      
      CERT_NAME="$$1"
      NAMESPACE="$$2"
      
      echo "$$(date): Renewing certificate $$CERT_NAME in namespace $$NAMESPACE"
      
      # Method 1: Add force-renewal annotation to trigger immediate renewal
      kubectl annotate certificate "$$CERT_NAME" \
        --namespace="$$NAMESPACE" \
        cert-manager.io/force-renewal="$$(date +%s)" \
        --overwrite
      
      # Method 2: Delete the secret to force recreation
      kubectl delete secret "$$CERT_NAME" \
        --namespace="$$NAMESPACE" \
        --ignore-not-found=true
      
      echo "$$(date): Certificate renewal triggered successfully"
      
      # Wait a moment and check status
      sleep 5
      kubectl get certificate "$$CERT_NAME" --namespace="$$NAMESPACE" -o json | \
        jq '.status.conditions[] | select(.type=="Ready") | .status'
    EOT

    "server.py" = <<-EOT
      #!/usr/bin/env python3
      import json
      import subprocess
      import sys
      from http.server import HTTPServer, BaseHTTPRequestHandler
      from urllib.parse import urlparse, parse_qs
      import logging
      
      logging.basicConfig(level=logging.INFO)
      logger = logging.getLogger(__name__)
      
      class RenewalHandler(BaseHTTPRequestHandler):
          def do_POST(self):
              if self.path == '/api/renew-cert':
                  self.handle_renewal()
              else:
                  self.send_error(404, "Not Found")
          
          def do_GET(self):
              if self.path == '/health':
                  self.send_response(200)
                  self.send_header('Content-Type', 'text/plain')
                  self.end_headers()
                  self.wfile.write(b'healthy')
              else:
                  self.send_error(404, "Not Found")
          
          def handle_renewal(self):
              try:
                  content_length = int(self.headers['Content-Length'])
                  post_data = self.rfile.read(content_length)
                  request_data = json.loads(post_data.decode('utf-8'))
                  
                  cert_name = request_data.get('certificate', 'nginx-demo-tls')
                  namespace = request_data.get('namespace', 'demo')
                  
                  logger.info(f"Renewing certificate {cert_name} in namespace {namespace}")
                  
                  # Execute the renewal script
                  result = subprocess.run([
                      '/bin/bash', '/scripts/renew-cert.sh', cert_name, namespace
                  ], capture_output=True, text=True)
                  
                  if result.returncode == 0:
                      response = {
                          "status": "success",
                          "message": f"Certificate {cert_name} renewal initiated",
                          "output": result.stdout.strip(),
                          "method": "force-renewal annotation + secret deletion"
                      }
                      self.send_json_response(200, response)
                  else:
                      response = {
                          "status": "error", 
                          "message": "Certificate renewal failed",
                          "error": result.stderr.strip()
                      }
                      self.send_json_response(500, response)
                      
              except Exception as e:
                  logger.error(f"Renewal error: {e}")
                  response = {
                      "status": "error",
                      "message": "Internal server error",
                      "error": str(e)
                  }
                  self.send_json_response(500, response)
          
          def send_json_response(self, code, data):
              self.send_response(code)
              self.send_header('Content-Type', 'application/json')
              self.send_header('Access-Control-Allow-Origin', '*')
              self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
              self.send_header('Access-Control-Allow-Headers', 'Content-Type')
              self.end_headers()
              self.wfile.write(json.dumps(data).encode('utf-8'))
          
          def log_message(self, format, *args):
              logger.info(f"{self.address_string()} - {format % args}")
      
      if __name__ == '__main__':
          server = HTTPServer(('0.0.0.0', 8080), RenewalHandler)
          logger.info("Certificate renewal server starting on port 8080")
          server.serve_forever()
    EOT
  }
}

# Note: Sidecar functionality is now integrated directly into the main deployment in phase3-vault-demo.tf