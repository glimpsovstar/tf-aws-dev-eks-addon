# Kubernetes Cluster Autoscaler
# Automatically scales EKS nodes based on pod resource demands

# Variables for Cluster Autoscaler
variable "install_cluster_autoscaler" {
  description = "Whether to install Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_version" {
  description = "Version of Cluster Autoscaler to install"
  type        = string
  default     = "9.37.0" # Latest Helm chart version
}

# IAM role for Cluster Autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  count = var.install_cluster_autoscaler ? 1 : 0
  
  name = "${local.eks_cluster_name}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.terraform_remote_state.eks_foundation.outputs.cluster_oidc_issuer_arn
        }
        Condition = {
          StringEquals = {
            "${replace(data.terraform_remote_state.eks_foundation.outputs.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(data.terraform_remote_state.eks_foundation.outputs.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${local.eks_cluster_name}-cluster-autoscaler"
    Environment = var.environment
  }
}

# IAM policy for Cluster Autoscaler
resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.install_cluster_autoscaler ? 1 : 0
  
  name        = "${local.eks_cluster_name}-cluster-autoscaler"
  description = "Policy for Cluster Autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count = var.install_cluster_autoscaler ? 1 : 0
  
  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
  role       = aws_iam_role.cluster_autoscaler[0].name
}

# Service Account for Cluster Autoscaler
resource "kubernetes_service_account" "cluster_autoscaler" {
  count = var.install_cluster_autoscaler ? 1 : 0

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler[0].arn
    }
  }

  automount_service_account_token = true
}

# Helm release for Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  count = var.install_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.cluster_autoscaler_version
  namespace  = "kube-system"

  values = [
    yamlencode({
      autoDiscovery = {
        clusterName = local.eks_cluster_name
        enabled     = true
      }
      
      awsRegion = var.aws_region
      
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.cluster_autoscaler[0].metadata[0].name
      }
      
      # Autoscaler configuration
      extraArgs = {
        # Scale down configuration
        "scale-down-delay-after-add"       = "10m"    # Wait 10min before scale down after scale up
        "scale-down-unneeded-time"         = "10m"    # Scale down after 10min of being unneeded
        "scale-down-delay-after-delete"    = "10s"    # Wait 10s before scale down after node deletion
        "scale-down-delay-after-failure"   = "3m"     # Wait 3min after scale down failure
        
        # Scale up configuration  
        "scale-down-utilization-threshold" = "0.5"    # Scale down when utilization < 50%
        "skip-nodes-with-local-storage"    = "false"  # Allow scaling down nodes with local storage
        "skip-nodes-with-system-pods"      = "false"  # Allow scaling down nodes with system pods
        
        # General configuration
        "balance-similar-node-groups"      = "false"  # Don't balance between similar node groups
        "expander"                         = "random" # Use random expander for node group selection
        "max-node-provision-time"          = "15m"    # Max time to wait for node to be provisioned
        "max-empty-bulk-delete"            = "10"     # Max number of empty nodes to delete at once
        "new-pod-scale-up-delay"           = "0s"     # No delay for new pods triggering scale up
        "scan-interval"                    = "10s"    # Scan for scale opportunities every 10s
      }
      
      # Resource limits
      resources = {
        limits = {
          cpu    = "100m"
          memory = "300Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "300Mi"
        }
      }
      
      # Node selector to run on system nodes
      nodeSelector = {}
      
      # Pod disruption budget
      podDisruptionBudget = {
        maxUnavailable = 1
      }
      
      # Pod annotations
      podAnnotations = {
        "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
      }
      
      # Image configuration
      image = {
        repository = "registry.k8s.io/autoscaling/cluster-autoscaler"
        # Version will be automatically selected based on Kubernetes version
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.cluster_autoscaler,
    aws_iam_role_policy_attachment.cluster_autoscaler
  ]
}

# Output Cluster Autoscaler information
output "cluster_autoscaler_role_arn" {
  description = "ARN of the Cluster Autoscaler IAM role"
  value       = var.install_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "cluster_autoscaler_service_account" {
  description = "Name of the Cluster Autoscaler service account"
  value       = var.install_cluster_autoscaler ? kubernetes_service_account.cluster_autoscaler[0].metadata[0].name : null
}