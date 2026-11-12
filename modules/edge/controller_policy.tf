# What the AWS Load Balancer Controller needs for its one job here:
# registering the API's pod addresses in the target group. It is the subset
# its documentation gives for TargetGroupBinding only, with the write
# actions limited to this one target group. It cannot create or change a
# load balancer, a listener, a security group or a WAF association.
#
# The controller has to start with --aws-region and --aws-vpc-id, because
# the nodes' metadata hop limit of 1 keeps it from reading them, and with its
# WAF and Shield features off, because this policy grants neither.

data "aws_iam_policy_document" "controller" {
  # Describe calls cannot be limited to one resource.
  statement {
    sid    = "Discover"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageTheApiTargets"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
    ]
    resources = [aws_lb_target_group.api.arn]
  }
}
