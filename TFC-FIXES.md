# TFC Apply Fixes Applied

## Issues Fixed

### 1. Route53 DNS Record Conflict
- **Problem**: DNS record `nginx-demo.dev.david-joo.sbx.hashidemos.io` already exists
- **Fix**: Added lifecycle `ignore_changes = [records]` and conditional creation
- **File**: `dns-records.tf`

### 2. Kubernetes Resource Conflicts  
- **Problem**: cert_renewal resources already exist, causing creation timeouts
- **Fix**: Added lifecycle `ignore_changes = [metadata[0].resource_version]` to all cert-renewal resources
- **Files**: `cert-renewal-sidecar.tf`, `phase3-vault-demo.tf`

### 3. Metrics Server Helm Timeout
- **Problem**: Helm chart installation taking >2.5 minutes, causing timeouts  
- **Fix**: Disabled Helm-based metrics server, documented manual installation
- **File**: `horizontal-pod-autoscaler.tf`

## Manual Steps Required After TFC Apply

### 1. Install Metrics Server (if not already installed)
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

### 2. Verify HPA Creation
```bash
# Wait for metrics server to be ready
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Check HPA status  
kubectl get hpa -n demo
```

### 3. Test Autoscaling (Optional)
```bash
# Test HPA
kubectl scale deployment nginx-demo --replicas=6 -n demo
watch 'kubectl get hpa -n demo && echo && kubectl get pods -n demo'

# Test Cluster Autoscaler  
kubectl scale deployment nginx-demo --replicas=15 -n demo
watch 'kubectl get nodes && echo && kubectl get pods -n demo'

# Cleanup
kubectl scale deployment nginx-demo --replicas=2 -n demo
```

## Expected TFC Apply Results

✅ **Should now succeed** with these resources:
- `kubernetes_deployment.load_generator[0]` - Load generator for testing
- `kubernetes_manifest.vault_cluster_issuer[0]` - Updated ClusterIssuer
- `kubernetes_horizontal_pod_autoscaler_v2.nginx_demo_hpa[0]` - HPA for nginx-demo
- Various cert-renewal resources (with lifecycle management)

❌ **Will skip** these problematic resources:
- `helm_release.metrics_server[0]` - Removed to avoid timeout
- `aws_route53_record.app_name_records["nginx-demo"]` - Conditional creation

## Website Status

The website should continue working at: https://nginx-demo.david-joo.sbx.hashidemos.io

The SSL certificates are working with token-based authentication to Vault.