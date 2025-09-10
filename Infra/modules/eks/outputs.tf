output "cluster_name" {
  value = aws_eks_cluster.cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}

output "node_group_name" {
  value = aws_eks_node_group.nodes.node_group_name
}
