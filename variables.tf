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
  description = "Karpenter Helm chart version. Leave blank to use chart's latest."
  type        = string
  default     = "1.7.4"
}
