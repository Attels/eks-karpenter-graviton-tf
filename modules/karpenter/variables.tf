variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "chart_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.7.4"
}
