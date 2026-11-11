output "bootstrap_brokers_sasl_iam" {
  description = "Brokers to connect to with SASL/IAM over TLS, port 9098."
  value       = aws_msk_cluster.kafka.bootstrap_brokers_sasl_iam
}

output "cluster_arn" {
  description = "ARN of the MSK cluster."
  value       = aws_msk_cluster.kafka.arn
}

output "cluster_name" {
  description = "Name of the MSK cluster."
  value       = aws_msk_cluster.kafka.cluster_name
}

output "app_policy_json" {
  description = "Permissions the API needs on the cluster, for its IRSA role."
  value       = data.aws_iam_policy_document.app.json
}
