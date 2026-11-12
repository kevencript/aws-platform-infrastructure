# What the API may do on the cluster: connect, and read and write the topics
# and consumer groups whose names start with its prefix. It cannot create,
# delete or reconfigure a topic, and it sees nothing outside its prefix.
#
# Kafka ACLs do not apply to IAM clients; these IAM actions are the access
# control.

locals {
  kafka_arn_prefix = "arn:${data.aws_partition.current.partition}:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"
  cluster_path     = "${aws_msk_cluster.kafka.cluster_name}/${aws_msk_cluster.kafka.cluster_uuid}"
}

data "aws_iam_policy_document" "app" {
  statement {
    sid    = "ConnectToTheCluster"
    effect = "Allow"
    actions = [
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeCluster",
      "kafka-cluster:WriteDataIdempotently",
    ]
    resources = [aws_msk_cluster.kafka.arn]
  }

  statement {
    sid    = "ReadAndWriteItsTopics"
    effect = "Allow"
    actions = [
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:ReadData",
      "kafka-cluster:WriteData",
    ]
    resources = ["${local.kafka_arn_prefix}:topic/${local.cluster_path}/${var.app_name_prefix}*"]
  }

  statement {
    sid    = "UseItsConsumerGroups"
    effect = "Allow"
    actions = [
      "kafka-cluster:DescribeGroup",
      "kafka-cluster:AlterGroup",
    ]
    resources = ["${local.kafka_arn_prefix}:group/${local.cluster_path}/${var.app_name_prefix}*"]
  }
}
