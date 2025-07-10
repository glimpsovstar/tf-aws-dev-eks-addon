# tf-aws-dev-eks-addon

Terraform module to manage EKS add-ons and related configurations.

## 📌 Overview

This module provisions additional AWS EKS cluster components.  
**It assumes that an EKS cluster is already created** and will leverage external data and outputs from the `tf-aws-dev-eks` workspace in Terraform Cloud (TFC).

Typical use cases include:
- Deploying ingress controllers
- Adding logging/monitoring integrations
- Managing extra IAM roles and policies
- Defining custom Kubernetes resources

## ✅ Requirements
- Terraform >= 1.3.x
- AWS Provider >= 4.x
- An existing EKS cluster provisioned by the tf-aws-dev-eks workspace
