# Vault Integration for cert-manager
# Phase 3: Connects cert-manager to HashiCorp Vault PKI

# Variables for Vault integration
variable "vault_addr" {
  description = "Vault server address"
  type        = string
  default     = "https://djoo-test-vault-public-vault-a40e8748.a3bc1cae.z1.hashicorp.cloud:8200"
}

variable "vault_token" {
  description = "Vault token for cert-manager authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "vault_namespace" {
  description = "Vault namespace"
  type        = string
  default     = "admin"
}

variable "vault_pki_path" {
  description = "Vault PKI mount path"
  type        = string
  default     = "pki-demo"
}

variable "vault_pki_role" {
  description = "Vault PKI role for Kubernetes certificates"
  type        = string
  default     = "kubernetes"
}

variable "install_vault_integration" {
  description = "Whether to install Vault PKI integration"
  type        = bool
  default     = false
}

# Vault token secret for cert-manager authentication
resource "kubernetes_secret" "vault_token" {
  count = var.install_vault_integration && var.vault_token != "" ? 1 : 0

  metadata {
    name      = "vault-token"
    namespace = "cert-manager"
  }

  data = {
    token = var.vault_token
  }

  type = "Opaque"

  depends_on = [helm_release.cert_manager]
}

# Vault ClusterIssuer for cert-manager
resource "kubernetes_manifest" "vault_cluster_issuer" {
  count = var.install_vault_integration && var.vault_addr != "" ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "vault-issuer"
    }
    spec = {
      vault = {
        server    = var.vault_addr
        path      = "${var.vault_pki_path}/sign/${var.vault_pki_role}"
        namespace = var.vault_namespace
        auth = {
          tokenSecretRef = {
            name = "vault-token"
            key  = "token"
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.cert_manager,
    kubernetes_secret.vault_token,
    time_sleep.wait_for_cert_manager
  ]
}