# Vault Integration for cert-manager
# Phase 3: Connects cert-manager to HashiCorp Vault PKI

# Variables for Vault integration
variable "vault_addr" {
  description = "Vault server address"
  type        = string
  default     = "https://djoo-test-vault-public-vault-a40e8748.a3bc1cae.z1.hashicorp.cloud:8200"
}

# Note: We use Kubernetes auth method, so no token variable needed

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

variable "vault_k8s_auth_path" {
  description = "Vault Kubernetes auth mount path"
  type        = string
  default     = "kubernetes"
}


# Note: Using Kubernetes auth method for cert-manager ServiceAccount
# The cert-manager ServiceAccount will authenticate directly to Vault using K8s JWT
# RBAC permissions are configured in cert-manager-rbac.tf

# Vault ClusterIssuer for cert-manager using Kubernetes auth
resource "kubernetes_manifest" "vault_cluster_issuer" {
  count = var.install_vault_integration && var.vault_addr != "" ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "vault-issuer"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      vault = {
        server    = "${var.vault_addr}/v1"
        path      = "${var.vault_namespace}/${var.vault_pki_path}/sign/${var.vault_pki_role}"
        auth = {
          kubernetes = {
            mountPath = "${var.vault_namespace}/auth/${var.vault_k8s_auth_path}"
            role      = "cert-manager"
            serviceAccountRef = {
              name = "cert-manager"
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.cert_manager,
    time_sleep.wait_for_cert_manager,
    kubernetes_cluster_role_binding.cert_manager_vault_auth
  ]
}