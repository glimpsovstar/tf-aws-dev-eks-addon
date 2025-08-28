# RBAC permissions for cert-manager to use Kubernetes auth with Vault
# This allows cert-manager to create ServiceAccount tokens for Vault authentication

resource "kubernetes_cluster_role" "cert_manager_vault_auth" {
  metadata {
    name = "cert-manager-vault-auth"
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts/token"]
    verbs      = ["create"]
  }
}

resource "kubernetes_cluster_role_binding" "cert_manager_vault_auth" {
  metadata {
    name = "cert-manager-vault-auth"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cert_manager_vault_auth.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "cert-manager"
    namespace = "cert-manager"
  }

  depends_on = [helm_release.cert_manager]
}