output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}
output "cluster_name" {
  value = aws_eks_cluster.this.name
}
output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.this.arn
}
output "irsa_workload_role_arn" {
  value = aws_iam_role.irsa_workload.arn
}
output "private_subnet_ids" {
  value = values(aws_subnet.private)[*].id
}
output "kubeconfig_helper_notes" {
  value = "From an approved network path, run: aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region <the region configured in the root provider>. Configure an EKS access entry before using kubectl."
}
