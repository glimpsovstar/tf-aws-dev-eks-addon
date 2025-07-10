terraform {
  cloud {
    organization = "djoo-hashicorp"
    workspaces {
      name = "tf-aws-dev-eks-addons"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Configure Kubernetes provider using data from foundation workspace
provider "kubernetes" {
  host                   = data.terraform_remote_state.eks_foundation.outputs.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_foundation.outputs.eks_certificate_authority)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.terraform_remote_state.eks_foundation.outputs.eks_cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

# Configure Helm provider using data from foundation workspace
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks_foundation.outputs.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_foundation.outputs.eks_certificate_authority)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        data.terraform_remote_state.eks_foundation.outputs.eks_cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}