output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "ecr_repo_uri" {
  value = aws_ecr_repository.app.repository_url
}

output "node_group_name" {
  value = aws_eks_node_group.ng.node_group_name
}
