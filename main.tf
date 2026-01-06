variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "minimal-eks"
}

variable "karpenter_chart_version" {
  description = "(Optional) Karpenter Helm chart version. Leave blank to use chart's latest."
  type        = string
  default     = "1.7.4"
}

terraform {
  required_version = ">= 1.5.0"

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

terraform {
  backend "local" {}
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}
