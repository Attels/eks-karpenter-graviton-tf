# Infra outputs
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.infra.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.infra.cluster_endpoint
}

# Karpenter outputs
output "karpenter_namespace" {
  description = "Karpenter namespace"
  value       = module.karpenter.namespace
}

output "karpenter_service_account" {
  description = "Karpenter service account"
  value       = module.karpenter.service_account
}

# Karpenter Resources outputs
output "provisioners" {
  description = "Karpenter provisioners created"
  value       = module.karpenter_resources.provisioners
}
