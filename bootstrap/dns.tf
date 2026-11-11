# The public hosted zone of the environment. It lives in this stack, not in
# the root module, for two reasons. The parent domain has to delegate to the
# zone before a certificate can be validated in it, and that is done outside
# this repository. And a zone that is deleted and created again gets new name
# servers, so the delegation would have to be redone.
resource "aws_route53_zone" "public" {
  name = var.domain_name

  lifecycle {
    prevent_destroy = true
  }
}
