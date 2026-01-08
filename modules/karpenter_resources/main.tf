terraform {
  required_version = ">= 1.14.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.28"
    }
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

# Fetch VPC and node IAM role
data "aws_vpc" "this" {
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

data "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-role"
}

# Security Group for Karpenter nodes
resource "aws_security_group" "karpenter" {
  name        = "${var.cluster_name}-karpenter-sg"
  description = "Security group assigned to nodes launched by Karpenter"
  vpc_id      = data.aws_vpc.this.id

  ingress {
    description     = "Allow EKS control plane to reach kubelet"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Allow EKS control plane to reach node HTTPS endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description = "Allow node-to-node traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                     = "${var.cluster_name}-karpenter-sg"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# Ensure the EKS Cluster Security Group is also discoverable by Karpenter
# so that Karpenter-launched nodes attach BOTH the cluster SG and the
# dedicated Karpenter node SG. This matches AWS/Karpenter best practices
# and avoids subtle control-plane connectivity issues.
resource "aws_ec2_tag" "eks_cluster_sg_discovery" {
  resource_id = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# EC2NodeClass for ARM64
resource "kubernetes_manifest" "karpenter_ec2nodeclass_arm64" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "karpenter-nodeclass-arm64"
    }
    spec = {
      amiFamily = "AL2023"
      role      = data.aws_iam_role.node_group.name
      amiSelectorTerms = [
        { id = "ami-00171c2155dff951e" }
      ]
      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } }
      ]
      securityGroupSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } }
      ]
    }
  }

  depends_on = [
    aws_security_group.karpenter,
  ]
}

# EC2NodeClass for AMD64
resource "kubernetes_manifest" "karpenter_ec2nodeclass_amd64" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "karpenter-nodeclass-amd64"
    }
    spec = {
      amiFamily = "AL2023"
      role      = data.aws_iam_role.node_group.name
      amiSelectorTerms = [
        { id = "ami-0713c16843cd14f6b" }
      ]
      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } }
      ]
      securityGroupSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } }
      ]
    }
  }

  depends_on = [
    aws_security_group.karpenter,
  ]
}

# NodePool for ARM64
resource "kubernetes_manifest" "karpenter_nodepool_arm64" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "karpenter-nodepool-arm64"
    }
    spec = {
      template = {
        spec = {
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["arm64"] },
            { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["c6g", "c7g", "m6g", "m7g", "r6g", "r7g"] },
            { key = "karpenter.k8s.aws/instance-size", operator = "In", values = ["medium"] },
            { key = "kubernetes.io/os", operator = "In", values = ["linux"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] }
          ]
          nodeClassRef = { group = "karpenter.k8s.aws", kind = "EC2NodeClass", name = "karpenter-nodeclass-arm64" }
          expireAfter  = "720h"
        }
      }
      limits = { cpu = "1000" }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.karpenter_ec2nodeclass_arm64
  ]
}

# NodePool for AMD64
resource "kubernetes_manifest" "karpenter_nodepool_amd64" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "karpenter-nodepool-amd64"
    }
    spec = {
      template = {
        spec = {
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            # { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["c5", "c6a", "c6i", "m5", "m6a", "m6i", "r5", "r6a", "r6i"] },
            { key = "karpenter.k8s.aws/instance-size", operator = "In", values = ["medium", "large"] },
            { key = "kubernetes.io/os", operator = "In", values = ["linux"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] }
          ]
          nodeClassRef = { group = "karpenter.k8s.aws", kind = "EC2NodeClass", name = "karpenter-nodeclass-amd64" }
          expireAfter  = "720h"
        }
      }
      limits = { cpu = "1000" }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.karpenter_ec2nodeclass_amd64,
  ]
}
