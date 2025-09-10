output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_nodegroup_name" {
  value = module.eks.node_group_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}
