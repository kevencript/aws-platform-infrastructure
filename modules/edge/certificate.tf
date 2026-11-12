# The TLS certificate of the API's host name, issued by ACM and validated
# through DNS: ACM asks for a record in the hosted zone, the record is
# created here, and ACM renews the certificate on its own for as long as the
# record stays.
#
# Validation completes only once the parent domain delegates to the hosted
# zone; until then the apply waits on it.

resource "aws_acm_certificate" "api" {
  domain_name       = var.hostname
  validation_method = "DNS"

  # A new certificate must exist before the listener lets go of the old one.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for option in aws_acm_certificate.api.domain_validation_options : option.domain_name => option
  }

  zone_id         = var.zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}
