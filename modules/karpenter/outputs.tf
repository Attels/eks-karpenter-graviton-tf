output "namespace" {
  description = "Karpenter namespace"
  value       = kubernetes_namespace.karpenter.metadata[0].name
}

output "service_account" {
  description = "Karpenter service account name"
  value       = kubernetes_service_account.karpenter.metadata[0].name
}

output "helm_release" {
  description = "Karpenter Helm release name"
  value       = helm_release.karpenter.id
}

output "karpenter_iam_role_arn" {
  description = "Karpenter IAM role ARN"
  value       = aws_iam_role.karpenter.arn
}
