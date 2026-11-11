# The root module wires the modules of the platform together. It creates no
# resource of its own: what it needs from the account, it looks up.

# The public hosted zone is created by the bootstrap stack, because it must
# outlive the environment. The root module finds it by name, so the two
# stacks share a name and no state.
data "aws_route53_zone" "public" {
  name         = var.domain_name
  private_zone = false
}
