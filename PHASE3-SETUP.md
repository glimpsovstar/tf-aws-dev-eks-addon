# Phase 3 Setup - Vault PKI Integration with EKS

## Prerequisites

Before running the EKS addon terraform, ensure the following are deployed:

### 1. Vault PKI Infrastructure
The vault-pki-demo terraform must be deployed first at:
`/Users/djoo/Documents/work-related/vault-related/vault-pki-demo/terraform`

This creates:
- PKI engine at `pki-demo/`
- Kubernetes auth method at `kubernetes/`
- cert-manager role in Kubernetes auth
- kubernetes role in PKI engine

Verify with:
```bash
cd /Users/djoo/Documents/work-related/vault-related/vault-pki-demo/terraform
terraform output
# Should show:
# kubernetes_auth_path = "kubernetes"
# cert_manager_role = "cert-manager"
# kubernetes_pki_role = "kubernetes"
```

### 2. EKS Foundation
The foundation EKS cluster must be deployed and accessible.

## Configuration

The Phase 3 integration uses these key configurations:

### Vault Settings (vault-issuer.tf)
- `vault_addr`: HCP Vault URL
- `vault_namespace`: "admin"
- `vault_pki_path`: "pki-demo"
- `vault_pki_role`: "kubernetes"
- `vault_k8s_auth_path`: "kubernetes" (mount path for K8s auth)

### Key Resources Created

1. **RBAC for cert-manager**
   - ClusterRoleBinding allowing cert-manager to authenticate to Vault
   - Uses system:auth-delegator role for token review API access

2. **Vault ClusterIssuer**
   - Configures cert-manager to use Vault PKI
   - Uses Kubernetes auth method (not token-based)
   - Path: `pki-demo/sign/kubernetes`

3. **Demo Application**
   - NGINX deployment with Vault-issued TLS certificates
   - Certificate auto-renewal via cert-manager
   - SSL monitoring website

## Deployment Steps

1. **Deploy Vault PKI Infrastructure** (if not already deployed)
```bash
cd /Users/djoo/Documents/work-related/vault-related/vault-pki-demo/terraform
terraform init
terraform apply
```

2. **Deploy EKS Addon with Phase 3**
```bash
cd /Users/djoo/Documents/work-related/TF-codes/tf-aws-dev-eks-addon
# Set variables in TFC or terraform.tfvars:
# install_vault_integration = true
# manage_existing_resources = true
terraform apply
```

3. **Install Metrics Server** (for autoscaling)
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

## Verification

1. **Check Vault Issuer Status**
```bash
kubectl get clusterissuer vault-issuer
kubectl describe clusterissuer vault-issuer
```

2. **Check Certificate Generation**
```bash
kubectl get certificate -n demo
kubectl describe certificate nginx-demo-tls -n demo
```

3. **Check Demo Application**
```bash
kubectl get pods -n demo
kubectl get svc -n demo
```

4. **Access Website**
```bash
# Should show SSL monitoring page with Vault-issued certificate
curl -k https://nginx-demo.david-joo.sbx.hashidemos.io
```

## Troubleshooting

### Certificate Not Ready
If certificates show as not ready:
1. Check vault-issuer status: `kubectl describe clusterissuer vault-issuer`
2. Check cert-manager logs: `kubectl logs -n cert-manager deployment/cert-manager`
3. Verify Vault auth: Check if cert-manager can authenticate to Vault

### Common Issues
- **"auth/kubernetes/login" not found**: Mount path should be "kubernetes" not "auth/kubernetes"
- **Permission denied**: Check cert-manager ClusterRoleBinding exists
- **Certificate request denied**: Verify Vault PKI role allows the requested domains

## Clean Up

To destroy and rebuild:
```bash
# Destroy EKS addon
terraform destroy

# Recreate (ensure manage_existing_resources = true)
terraform apply
```

The system is designed to be idempotent - you can safely destroy and recreate.