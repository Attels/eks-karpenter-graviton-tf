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

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

data "aws_caller_identity" "current" {}

data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  depends_on = [data.aws_eks_cluster.this]
}

resource "aws_iam_role" "karpenter" {
  name = "${var.cluster_name}-karpenter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })
}

data "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-role"
}

resource "aws_iam_instance_profile" "node_profile" {
  name = "${var.cluster_name}-node-profile"
  role = data.aws_iam_role.node_group.name
}

resource "aws_iam_role_policy" "karpenter_policy" {
  name = "${var.cluster_name}-karpenter-policy"
  role = aws_iam_role.karpenter.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeImages",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstances",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeAvailabilityZones",
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate",
          "ec2:ModifyInstanceAttribute",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["iam:ListInstanceProfiles"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["iam:PassRole"],
        Resource = [data.aws_iam_role.node_group.arn]
      },
      {
        Effect   = "Allow",
        Action   = ["ssm:GetParameters", "ssm:GetParameter"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:ReceiveMessage"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:CreateInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["pricing:GetProducts"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["eks:DescribeCluster"],
        Resource = [data.aws_eks_cluster.this.arn]
      }
    ]
  })
}

resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }
}

resource "kubernetes_service_account" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = kubernetes_namespace.karpenter.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn"     = aws_iam_role.karpenter.arn
      "meta.helm.sh/release-name"      = "karpenter"
      "meta.helm.sh/release-namespace" = "karpenter"
    }
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }

  depends_on = [aws_iam_role.karpenter, aws_iam_openid_connect_provider.eks]
}

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = var.cluster_name
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "karpenter_interruption_policy" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowEventBridgeSendMessage",
        Effect    = "Allow",
        Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.karpenter_interruption.arn
      }
    ]
  })
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.chart_version
  namespace  = kubernetes_namespace.karpenter.metadata[0].name

  values = [yamlencode({
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter.arn
      }
    }

    replicas = 1

    settings = {
      clusterName       = data.aws_eks_cluster.this.name
      interruptionQueue = aws_sqs_queue.karpenter_interruption.name
    }

    controller = {
      clusterName     = data.aws_eks_cluster.this.name
      clusterEndpoint = data.aws_eks_cluster.this.endpoint
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.karpenter.metadata[0].name
      }
    }
  })]

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    kubernetes_service_account.karpenter,
    aws_sqs_queue.karpenter_interruption,
  ]

  # Add provisioner to wait for CRDs after Helm deployment
  provisioner "local-exec" {
    when       = create
    command    = "sleep 60"
    on_failure = continue
  }
}
