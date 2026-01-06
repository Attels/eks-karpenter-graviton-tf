resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = [aws_subnet.this.id]

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  instance_types = ["t4g.small"]
  ami_type       = "BOTTLEROCKET_ARM_64"
  capacity_type  = "ON_DEMAND"

  tags = {
    Name = "${var.cluster_name}-node"
  }
}
