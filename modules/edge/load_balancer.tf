# The internet-facing Application Load Balancer, its two listeners, the
# target group of the API's pods and the DNS name that points at it.
#
# Terraform owns all of it. Inside the cluster, the AWS Load Balancer
# Controller has one job: keep the target group filled with the addresses of
# the API's pods (a TargetGroupBinding). Until it does, the group is empty
# and the load balancer answers 503.

# The load balancer is public on purpose: it is the platform's only entry
# point from the internet.
#trivy:ignore:AWS-0053
resource "aws_lb" "api" {
  name               = "${var.name_prefix}-api"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [var.security_group_id]

  # Requests with header names that are not valid HTTP are dropped instead of
  # being passed to the API.
  drop_invalid_header_fields = true

  # Deleting the load balancer takes the API off the internet. It is turned
  # off in code first, as a reviewed change.
  enable_deletion_protection = true
}

# Targets are pod addresses, not nodes: traffic goes straight to a pod, and
# the health check tests each pod.
resource "aws_lb_target_group" "api" {
  name        = "${var.name_prefix}-api"
  target_type = "ip"
  protocol    = "HTTP"
  port        = var.app_port
  vpc_id      = var.vpc_id

  # Time a pod being removed gets to finish the requests it holds.
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"

  # TLS 1.2 and 1.3 only. Left unset, the listener would accept TLS 1.0.
  ssl_policy = var.ssl_policy

  # The validated certificate, so the listener waits for validation.
  certificate_arn = aws_acm_certificate_validation.api.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# Port 80 only redirects to HTTPS. No request is served in plain text.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_route53_record" "api" {
  zone_id = var.zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = aws_lb.api.dns_name
    zone_id                = aws_lb.api.zone_id
    evaluate_target_health = true
  }
}
