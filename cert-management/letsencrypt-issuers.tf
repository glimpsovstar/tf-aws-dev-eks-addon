# Let's Encrypt ClusterIssuers
# Provides free SSL certificates via ACME protocol

variable "create_letsencrypt_issuers" {
  description = "Whether to create Let's Encrypt ClusterIssuers"
  type        = bool
  default     = false
}

# Let's Encrypt Production ClusterIssuer
resource "kubernetes_manifest" "letsencrypt_prod_issuer" {
  count = var.create_letsencrypt_issuers && var.letsencrypt_email != "" ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = var.letsencrypt_email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [
    helm_release.cert_manager,
    time_sleep.wait_for_cert_manager
  ]
}

# Let's Encrypt Staging ClusterIssuer
resource "kubernetes_manifest" "letsencrypt_staging_issuer" {
  count = var.create_letsencrypt_issuers && var.letsencrypt_email != "" ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        email  = var.letsencrypt_email
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-staging"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [
    helm_release.cert_manager,
    time_sleep.wait_for_cert_manager
  ]
}