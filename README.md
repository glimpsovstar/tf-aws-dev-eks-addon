# EKS Add-ons Workspace

This workspace manages Kubernetes add-ons and applications on top of the EKS cluster provisioned by the `tf-aws-dev-eks` workspace.

## Architecture

```
tf-aws-dev-eks (Foundation)
    ↓
tf-aws-dev-eks-addon (Add-ons)
    ├── NGINX Ingress Controller
    ├── cert-manager
    ├── Vault PKI Integration (Phase 3)
    ├── Storage Classes
    └── Demo Applications
```

## Directory Structure

```
tf-aws-dev-eks-addon/
├── main.tf                    # Data sources and locals
├── variables.tf               # Input variables
├── outputs.tf                 # Outputs
├── provider.tf                # Provider configurations
├── versions.tf                # Version requirements
│
├── ingress/                   # Ingress controllers
│   ├── nginx-ingress.tf       # NGINX Ingress Controller
│   └── dns-records.tf         # Route53 DNS records
│
├── cert-management/           # Certificate management
│   ├── cert-manager.tf        # cert-manager installation
│   ├── vault-issuer.tf        # Vault PKI integration (Phase 3)
│   └── letsencrypt-issuers.tf # Let's Encrypt ClusterIssuers
│
├── storage/                   # Storage classes
│   └── storage-classes.tf     # GP3, IO2, Vault storage
│
├── demo-apps/                 # Demo applications
│   └── phase3-vault-demo.tf   # Phase 3 Vault certificate demo
│
└── manifests/                 # Manual Kubernetes manifests
    └── cluster-issuers.yaml   # Legacy ClusterIssuer definitions
```

## Key Features

### ✅ **Modular Design**
- Organized by function (ingress, cert-management, storage, etc.)
- Easy to enable/disable individual components
- Clear separation of concerns

### ✅ **Phase 3 Ready**
- Vault PKI integration via cert-manager
- Automatic certificate provisioning
- Demo applications with Vault-issued certificates

### ✅ **Production Ready**
- Let's Encrypt integration option
- High-performance storage classes
- Resource optimization

## Usage

### Basic Deployment (NGINX + cert-manager)
```bash
# In TFC workspace: tf-aws-dev-eks-addon
install_nginx_ingress = true
install_cert_manager  = true
```

### Phase 3 Vault Integration
```bash
# Enable Vault PKI integration
install_vault_integration = true
vault_token = "hvs.xxxxx"  # From HCP Vault
```

### Let's Encrypt Integration
```bash
# Enable Let's Encrypt
create_letsencrypt_issuers = true
letsencrypt_email = "your@email.com"
```

## Variable Groups

### **Core Infrastructure**
- `install_nginx_ingress` - NGINX Ingress Controller
- `install_cert_manager` - cert-manager for certificates
- `create_storage_classes` - Additional storage classes

### **DNS Configuration**
- `app_dns_records` - DNS records for applications
- `create_wildcard_dns` - Wildcard DNS support
- `wildcard_domain` - Wildcard domain pattern

### **Certificate Management**
- `letsencrypt_email` - Let's Encrypt contact email
- `create_letsencrypt_issuers` - Let's Encrypt ClusterIssuers

### **Vault Integration (Phase 3)**
- `install_vault_integration` - Enable Vault PKI
- `vault_addr` - Vault server address
- `vault_token` - Vault authentication token
- `vault_namespace` - Vault namespace (admin)
- `vault_pki_path` - PKI engine path (pki-demo)
- `vault_pki_role` - PKI role for K8s (kubernetes)

## Dependencies

### **Required Foundation**
- EKS cluster from `tf-aws-dev-eks` workspace
- Route53 hosted zone
- VPC and networking infrastructure

### **TFC Integration**
- Run triggers from foundation workspace
- Shared variable sets for common configuration
- Automatic deployment after EKS cluster changes

## Deployment Order

1. **Foundation**: Deploy `tf-aws-dev-eks` first
2. **Basic Add-ons**: Enable ingress and cert-manager
3. **Phase 3**: Configure Vault integration
4. **Applications**: Deploy demo applications

## Outputs

### **Infrastructure**
- `ingress_load_balancer_hostname` - NGINX LoadBalancer URL
- `cert_manager_installed` - cert-manager status
- `eks_cluster_name` - EKS cluster reference

### **DNS**
- `dns_records_created` - Created DNS records
- `wildcard_dns_created` - Wildcard DNS status

### **Certificates**
- `letsencrypt_cluster_issuer_prod` - Production issuer name
- `vault_cluster_issuer` - Vault issuer name (Phase 3)

## Troubleshooting

### **Common Issues**

1. **LoadBalancer Pending**: Check AWS quotas and security groups
2. **Certificate Pending**: Verify issuer configuration and DNS
3. **Ingress Not Working**: Check LoadBalancer and DNS propagation

### **Debug Commands**
```bash
# Check cert-manager status
kubectl get certificate -A
kubectl describe certificate <name> -n <namespace>

# Check ClusterIssuers
kubectl get clusterissuer
kubectl describe clusterissuer <name>

# Check ingress
kubectl get ingress -A
kubectl describe ingress <name> -n <namespace>
```

## Phase 3 Demo

The Phase 3 demo showcases automatic certificate provisioning from HashiCorp Vault:

1. **Certificate Request**: cert-manager requests certificate from Vault
2. **Automatic Issuance**: Vault issues certificate using PKI engine
3. **Secret Creation**: Certificate stored as Kubernetes secret
4. **Pod Mounting**: Application automatically uses the certificate
5. **Auto-Renewal**: cert-manager renews before expiration

Access the demo at: `https://nginx-demo.david-joo.sbx.hashidemos.io`

## Next Steps

- [ ] Add monitoring stack (Prometheus/Grafana)
- [ ] Implement service mesh integration
- [ ] Add security tools (Falco, OPA)
- [ ] Create GitOps workflows