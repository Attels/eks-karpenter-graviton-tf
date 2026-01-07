resource "aws_security_group" "karpenter" {
  name        = "${var.cluster_name}-karpenter-sg"
  description = "Security group assigned to nodes launched by Karpenter"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Allow EKS control plane to reach kubelet"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Allow EKS control plane to reach node HTTPS endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
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

resource "kubernetes_manifest" "karpenter_ec2nodeclass_arm64" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "karpenter-nodeclass-arm64"
    }
    spec = {
      amiFamily = "AL2023"
      role      = aws_iam_role.node_group.name
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

  #depends_on = [helm_release.karpenter, kubernetes_service_account.karpenter, kubernetes_manifest.karpenter_crd_ec2nodeclasses]
  depends_on = [helm_release.karpenter, kubernetes_service_account.karpenter]

}

resource "kubernetes_manifest" "karpenter_ec2nodeclass_amd64" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "karpenter-nodeclass-amd64"
    }
    spec = {
      amiFamily = "AL2023"
      role      = aws_iam_role.node_group.name
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

  #   depends_on = [helm_release.karpenter, kubernetes_service_account.karpenter, kubernetes_manifest.karpenter_crd_ec2nodeclasses]
  depends_on = [helm_release.karpenter, kubernetes_service_account.karpenter]
}

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
            { key = "karpenter.k8s.aws/instance-category", operator = "In", values = ["m"] },
            { key = "karpenter.k8s.aws/instance-size", operator = "NotIn", values = ["nano"] },
            { key = "kubernetes.io/os", operator = "In", values = ["linux"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] }
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

  # depends_on = [kubernetes_manifest.karpenter_ec2nodeclass_arm64, kubernetes_manifest.karpenter_crd_nodepools]
}


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
            { key = "karpenter.k8s.aws/instance-size", operator = "NotIn", values = ["nano"] },
            { key = "kubernetes.io/os", operator = "In", values = ["linux"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] }
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

  # depends_on = [kubernetes_manifest.karpenter_ec2nodeclass_amd64, kubernetes_manifest.karpenter_crd_nodepools]
}

# resource "kubernetes_manifest" "karpenter_crd_nodepools" {
#   manifest = {
#     apiVersion = "apiextensions.k8s.io/v1"
#     kind       = "CustomResourceDefinition"
#     metadata = {
#       name = "nodepools.karpenter.sh"
#     }
#     spec = {
#       group = "karpenter.sh"
#       names = {
#         plural   = "nodepools"
#         singular = "nodepool"
#         kind     = "NodePool"
#       }
#       scope = "Cluster"
#       versions = [
#         {
#           name    = "v1"
#           served  = true
#           storage = true
#         }
#       ]
#     }
#   }
# }

# resource "kubernetes_manifest" "karpenter_crd_ec2nodeclasses" {
#   manifest = {
#     apiVersion = "apiextensions.k8s.io/v1"
#     kind       = "CustomResourceDefinition"
#     metadata = {
#       name = "ec2nodeclasses.karpenter.k8s.aws"
#     }
#     spec = {
#       group = "karpenter.k8s.aws"
#       names = {
#         plural   = "ec2nodeclasses"
#         singular = "ec2nodeclass"
#         kind     = "EC2NodeClass"
#       }
#       scope = "Cluster"
#       versions = [
#         {
#           name    = "v1"
#           served  = true
#           storage = true
#         }
#       ]
#     }
#   }
# }
