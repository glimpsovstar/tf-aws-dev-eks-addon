# Storage Classes for EKS
# Defines storage options for persistent volumes

variable "create_storage_classes" {
  description = "Whether to create additional storage classes"
  type        = bool
  default     = true
}

# GP3 Storage Class (default for most workloads)
resource "kubernetes_storage_class" "gp3" {
  count = var.create_storage_classes ? 1 : 0

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    throughput = "125"
    iops       = "3000"
  }
}

# GP3 Storage Class for Vault (high performance)
resource "kubernetes_storage_class" "vault_storage" {
  count = var.create_storage_classes ? 1 : 0

  metadata {
    name = "vault-storage"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    throughput = "250"  # Higher throughput for Vault
    iops       = "4000" # Higher IOPS for Vault
  }
}

# IO2 Storage Class (for high-performance workloads)
resource "kubernetes_storage_class" "io2" {
  count = var.create_storage_classes ? 1 : 0

  metadata {
    name = "io2"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "io2"
    encrypted = "true"
    iops      = "1000"
  }
}