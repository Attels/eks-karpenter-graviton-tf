output "provisioners" {
  description = "Karpenter provisioners created"
  value = concat(
    [kubernetes_manifest.karpenter_ec2nodeclass_arm64.object.metadata.name],
    [kubernetes_manifest.karpenter_ec2nodeclass_amd64.object.metadata.name],
    [kubernetes_manifest.karpenter_nodepool_arm64.object.metadata.name],
    [kubernetes_manifest.karpenter_nodepool_amd64.object.metadata.name],
  )
}

output "security_group_id" {
  description = "Karpenter security group ID"
  value       = aws_security_group.karpenter.id
}
