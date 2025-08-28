# Kubernetes Autoscaling Setup

## Overview

This setup implements **three levels of autoscaling** for optimal resource utilization and cost efficiency:

1. **Horizontal Pod Autoscaler (HPA)** - Scales pods based on CPU/memory usage
2. **Cluster Autoscaler** - Scales nodes based on pod resource demands  
3. **Vertical Pod Autoscaler (VPA)** - Provides resource recommendations

## Components Created

### 1. Cluster Autoscaler (`cluster-autoscaler.tf`)

**Purpose**: Automatically add/remove EKS nodes based on pod scheduling needs

**Features**:
- ✅ Auto-discovery of node groups via tags
- ✅ Scale up when pods can't be scheduled
- ✅ Scale down when nodes are underutilized (<50% utilization)
- ✅ IRSA (IAM Roles for Service Accounts) integration
- ✅ Intelligent scaling delays to prevent thrashing

**Configuration**:
```yaml
Min Nodes: 2 (always running)
Max Nodes: 6 (scale up when needed)
Scale Down Threshold: 50% utilization
Scale Down Delay: 10 minutes after scale up
```

### 2. Horizontal Pod Autoscaler (`horizontal-pod-autoscaler.tf`)

**Purpose**: Scale nginx-demo pods based on resource usage

**Metrics**:
- CPU usage > 70% → Scale up
- Memory usage > 80% → Scale up
- Pod range: 2-10 replicas

**Behavior**:
- **Scale Up**: Double pods or add 2 pods (whichever is less)
- **Scale Down**: Reduce by 50% or 1 pod (whichever is less) after 5 min

### 3. Metrics Server

**Purpose**: Provides resource usage metrics for HPA

**Features**:
- ✅ 15-second metric resolution
- ✅ Secure TLS communication
- ✅ Optimized for EKS

## Foundation EKS Updates Required

Update your **foundation EKS configuration** (`/tf-aws-dev-eks/main.tf`) with these autoscaling tags:

```hcl
eks_managed_node_groups = {
  default = {
    # Autoscaling configuration
    min_size       = 2     # Minimum nodes
    max_size       = 6     # Maximum nodes  
    desired_size   = 2     # Starting nodes
    
    instance_types = [var.instance_type]
    capacity_type  = "ON_DEMAND"
    
    # REQUIRED: Autoscaling tags for Cluster Autoscaler discovery
    tags = {
      "k8s.io/cluster-autoscaler/enabled" = "true"
      "k8s.io/cluster-autoscaler/${var.eks_cluster_name}" = "owned"
    }
    
    # Optional: Better performance configuration
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size = 50
          volume_type = "gp3"
          iops        = 3000
          encrypted   = true
        }
      }
    }
  }
}
```

## Deployment Steps

1. **Update Foundation EKS** (required):
   ```bash
   cd /Users/djoo/Documents/work-related/TF-codes/tf-aws-dev-eks
   # Add the autoscaling tags to main.tf
   terraform plan
   terraform apply
   ```

2. **Deploy Addon Autoscaling**:
   ```bash
   cd /Users/djoo/Documents/work-related/TF-codes/tf-aws-dev-eks-addon
   terraform plan
   terraform apply  # Or run TFC apply
   ```

## How It Works

### Scaling Scenarios

**Scenario 1: Traffic Surge**
1. nginx-demo pods get high CPU/memory usage
2. **HPA** scales pods from 2 → 4 → 6 → 8
3. New pods can't be scheduled (insufficient nodes)
4. **Cluster Autoscaler** adds new nodes (2 → 3 → 4)
5. Pods get scheduled on new nodes

**Scenario 2: Traffic Drops**
1. Pod usage drops below thresholds
2. **HPA** scales pods down after 5 minutes
3. Nodes become underutilized (<50% usage)
4. **Cluster Autoscaler** removes excess nodes after 10 minutes

### Resource Efficiency

- **Cost Savings**: Only pay for nodes you need
- **Performance**: Automatic scaling prevents overload
- **Resilience**: Always maintain minimum capacity

## Monitoring Autoscaling

```bash
# Check HPA status
kubectl get hpa -n demo

# Check Cluster Autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Check node utilization
kubectl top nodes

# Check pod utilization  
kubectl top pods -n demo

# Check VPA recommendations
kubectl get vpa -n demo
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `install_cluster_autoscaler` | `true` | Enable autoscaling components |
| `cluster_autoscaler_version` | `9.37.0` | Helm chart version |

## Troubleshooting

### Common Issues

1. **HPA shows "unknown" metrics**
   - Check Metrics Server: `kubectl get pods -n kube-system | grep metrics-server`
   - Wait 2-3 minutes for metrics collection

2. **Cluster Autoscaler not scaling**
   - Check autoscaling tags on node groups
   - Verify IAM permissions
   - Check logs: `kubectl logs -n kube-system deployment/cluster-autoscaler`

3. **Pods not scaling**
   - Ensure resource requests are set on containers
   - Check HPA configuration: `kubectl describe hpa -n demo`

## Benefits of This Setup

✅ **Automatic scaling** - No manual intervention needed  
✅ **Cost optimization** - Scale down during low usage  
✅ **Performance** - Scale up during high demand  
✅ **Resilience** - Maintain minimum capacity always  
✅ **Intelligent** - Multiple metrics and stabilization windows  
✅ **Observable** - Full monitoring and logging integration