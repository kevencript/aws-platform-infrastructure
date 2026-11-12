# Pressure on the EKS nodes.
#
# The CloudWatch agent publishes node metrics to Container Insights. Over
# the cluster dimension, the Maximum statistic follows the busiest node,
# which is the one about to run out. Silence counts as a problem: without
# the agent there is no data, and nobody would know the nodes are unwatched.

locals {
  node_pressure = {
    cpu        = "node_cpu_utilization"
    memory     = "node_memory_utilization"
    filesystem = "node_filesystem_utilization"
  }
}

resource "aws_cloudwatch_metric_alarm" "node_pressure" {
  for_each = local.node_pressure

  alarm_name        = "${var.name_prefix}-nodes-${each.key}"
  alarm_description = "A node of ${var.cluster_name} has used more than 80% of its ${each.key} for 15 minutes, or the CloudWatch agent stopped reporting."

  namespace   = "ContainerInsights"
  metric_name = each.value
  dimensions  = { ClusterName = var.cluster_name }

  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 80
  treat_missing_data  = "breaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

# CPU of the node group's instances, from EC2 itself. It works without the
# agent: if the Container Insights alarms above cannot get data, this one
# still sees CPU pressure.
resource "aws_cloudwatch_metric_alarm" "node_group_cpu" {
  alarm_name        = "${var.name_prefix}-node-group-cpu"
  alarm_description = "The EKS nodes of ${var.cluster_name} average more than 80% CPU for 15 minutes."

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  dimensions  = { AutoScalingGroupName = var.node_group_autoscaling_group_name }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 80
  treat_missing_data  = "missing"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}
