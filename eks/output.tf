output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.eks-cluster.name
}

output "eks_cluster_endpoint" {
  description = "The endpoint URL for the EKS cluster API server"
  value       = aws_eks_cluster.eks-cluster.endpoint
}

output "eks_cluster_certificate_authority" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.eks-cluster.certificate_authority[0].data
}

output "eks_cluster_version" {
  description = "The Kubernetes server version of the EKS cluster"
  value       = aws_eks_cluster.eks-cluster.version
}

output "eks_node_group_name" {
  description = "The name of the EKS managed node group"
  value       = aws_eks_node_group.eks-node-group.node_group_name
}

output "eks_node_group_status" {
  description = "The status of the EKS node group"
  value       = aws_eks_node_group.eks-node-group.status
}

output "eks_cluster_role_arn" {
  description = "The ARN of the IAM role used by the EKS cluster"
  value       = aws_iam_role.EKSClusterRole.arn
}

output "eks_node_group_role_arn" {
  description = "The ARN of the IAM role used by the EKS node group"
  value       = aws_iam_role.NodeGroupRole.arn
}

output "eks_kubeconfig_command" {
  description = "Command to update kubeconfig for cluster access"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.eks-cluster.name} --region us-east-1"
}
