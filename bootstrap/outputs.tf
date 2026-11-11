# Each output has one reader outside this stack.

output "backend_config" {
  description = "The exact content that environments/<env>/backend.hcl must have. Compare the two after the first apply."
  value       = <<-EOT
    # Where this account keeps Terraform state. Both stacks read this file:
    #   terraform init -backend-config=<this file>
    # Each stack names its own object key in its backend block.
    # encrypt and kms_key_id go together: encrypt alone would store the state
    # under an S3 managed key instead of the state key.
    bucket         = "${aws_s3_bucket.state.id}"
    region         = "${var.aws_region}"
    dynamodb_table = "${aws_dynamodb_table.lock.name}"
    encrypt        = true
    kms_key_id     = "${aws_kms_alias.state.name}"
  EOT
}

output "name_servers" {
  description = "Name servers of the public hosted zone. The parent domain needs an NS record for the zone name with these values."
  value       = aws_route53_zone.public.name_servers
}
