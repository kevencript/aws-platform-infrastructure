# Kafka and the load balancer. MSK's dimension names contain spaces.

# A partition without a leader accepts no reads and no writes.
resource "aws_cloudwatch_metric_alarm" "kafka_offline_partitions" {
  alarm_name        = "${var.name_prefix}-kafka-offline-partitions"
  alarm_description = "Kafka has partitions without a leader: they accept no reads and no writes."

  namespace   = "AWS/Kafka"
  metric_name = "OfflinePartitionsCount"
  dimensions  = { "Cluster Name" = var.kafka_cluster_name }

  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

# A broker whose disk fills up stops accepting writes. MSK numbers brokers
# from 1.
resource "aws_cloudwatch_metric_alarm" "kafka_disk" {
  for_each = toset([for index in range(var.kafka_broker_count) : tostring(index + 1)])

  alarm_name        = "${var.name_prefix}-kafka-broker-${each.value}-disk"
  alarm_description = "Kafka broker ${each.value} has used more than 80% of its data disk."

  namespace   = "AWS/Kafka"
  metric_name = "KafkaDataLogsDiskUsed"
  dimensions = {
    "Cluster Name" = var.kafka_cluster_name
    "Broker ID"    = each.value
  }

  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 80
  treat_missing_data  = "missing"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

# The API answers with server errors. Counts from the pods, not from the load
# balancer, so an empty target group does not count here.
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name        = "${var.name_prefix}-api-5xx"
  alarm_description = "The API returned more than ${var.api_5xx_threshold} server errors in 5 minutes."

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"
  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.api_5xx_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

# A pod fails its health check for three minutes in a row.
resource "aws_cloudwatch_metric_alarm" "api_unhealthy_targets" {
  alarm_name        = "${var.name_prefix}-api-unhealthy-targets"
  alarm_description = "At least one API pod has failed the load balancer's health check for 3 minutes."

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"
  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}
