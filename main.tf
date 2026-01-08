terraform {
  required_version = ">= 1.14.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.28"
    }
  }
}

provider "aws" {
  region = var.region
}

# Module 1: Infrastructure (VPC, EKS, IAM, Node Groups)
module "infra" {
  source = "./modules/infra"

  region       = var.region
  cluster_name = var.cluster_name

  providers = {
    aws = aws
  }
}

# Configure providers for Kubernetes and Helm after cluster is created
data "aws_eks_cluster" "this" {
  name       = module.infra.cluster_name
  depends_on = [module.infra]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.infra.cluster_name
  depends_on = [module.infra]
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Module 2: Karpenter Helm Chart
module "karpenter" {
  source = "./modules/karpenter"

  region           = var.region
  cluster_name     = module.infra.cluster_name
  cluster_endpoint = module.infra.cluster_endpoint
  chart_version    = var.karpenter_chart_version

  providers = {
    aws        = aws
    helm       = helm
    kubernetes = kubernetes
  }

  depends_on = [module.infra]
}

# Module 3: Karpenter Provisioners & Resources
module "karpenter_resources" {
  source = "./modules/karpenter_resources"

  region           = var.region
  cluster_name     = module.infra.cluster_name
  cluster_endpoint = module.infra.cluster_endpoint
  service_account  = module.karpenter.service_account

  providers = {
    aws        = aws
    kubernetes = kubernetes
  }

  depends_on = [module.karpenter]
}
