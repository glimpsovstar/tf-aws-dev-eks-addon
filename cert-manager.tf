# cert-manager Installation
# Provides automatic certificate management for Kubernetes

resource "helm_release" "cert_manager" {
  count            = var.install_cert_manager ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.15.3"  # Updated to latest version
  namespace        = "cert-manager"
  create_namespace = true
  timeout          = 600
  wait             = true
  wait_for_jobs    = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "extraArgs[0]"
    value = "--enable-certificate-owner-ref=true"
  }

  # Add prometheus metrics
  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  depends_on = [
    data.terraform_remote_state.eks_foundation
  ]
}

# Wait for cert-manager to be fully ready
resource "time_sleep" "wait_for_cert_manager" {
  count           = var.install_cert_manager ? 1 : 0
  depends_on      = [helm_release.cert_manager]
  create_duration = "120s"
}