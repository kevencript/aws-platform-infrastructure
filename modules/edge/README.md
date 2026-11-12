# edge

The API's public entry point: a TLS certificate, an internet-facing Application Load
Balancer, a WAF web ACL in front of it, and the host name that points at it.

| File | What it creates |
|------|-----------------|
| `certificate.tf` | ACM certificate for the host name, validated through a record in the hosted zone |
| `load_balancer.tf` | Load balancer, HTTPS and HTTP listeners, the `ip` target group, the alias record |
| `waf.tf` | Web ACL with a rate limit and three AWS managed rule groups, its association, and its logs |
| `controller_policy.tf` | The permissions the AWS Load Balancer Controller needs, published as an output |

## How a request reaches a pod

1. The client resolves the host name, an alias of the load balancer.
2. The WAF evaluates the request: rate limit, then reputation list, then the common and
   known-bad-input rule sets.
3. Port 80 answers with a redirect to HTTPS. Port 443 terminates TLS 1.2 or 1.3 with the
   ACM certificate.
4. The listener forwards to the target group, whose targets are pod addresses on the API
   port. Each pod is health checked on its own.

Terraform owns every part of this path. In the cluster, the AWS Load Balancer Controller
only keeps the target group filled with the API's pod addresses, through a
`TargetGroupBinding` that names `target_group_name`. Until that binding exists, the
target group is empty and the load balancer answers 503. The controller must start with
`--aws-region` and `--aws-vpc-id`, because the nodes' metadata hop limit of 1 keeps it
from reading them, and with its WAF and Shield features off.

## What to know

- **TLS policy.** Left unset, an HTTPS listener accepts TLS 1.0. The default here allows
  TLS 1.2 and 1.3 only.
- **Certificate validation waits for DNS.** It completes only once the parent domain
  delegates to the hosted zone.
- **WAF logs keep only what the WAF blocked or counted,** with the `authorization` and
  `cookie` headers redacted.
- **The common rule set's body size rule only counts.** It would block request bodies
  above 8 KB, which a JSON API can send legitimately.
- **Deletion protection is on.** Removing the load balancer is a reviewed change in code.
- **The controller's write actions are limited to the one target group.** It cannot
  create or change a load balancer, a listener, a security group or a WAF association.

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `name_prefix` | `string` | `<project>-<environment>`, at most 28 characters |
| `hostname` | `string` | Host name of the API, inside the hosted zone |
| `zone_id` | `string` | The public hosted zone |
| `vpc_id`, `public_subnet_ids` | | From `modules/networking` |
| `security_group_id`, `app_port` | | From `modules/security` |
| `health_check_path` | `string` | Default: `/healthz` |
| `ssl_policy` | `string` | Default: `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09` |
| `waf_rate_limit` | `number` | Requests per address in five minutes. Default: 2000 |
| `log_retention_days` | `number` | Retention of the WAF logs |

## Outputs

| Name | Description |
|------|-------------|
| `url` | `https://<hostname>` |
| `load_balancer_arn`, `load_balancer_dns_name`, `load_balancer_arn_suffix` | The load balancer |
| `target_group_arn`, `target_group_name`, `target_group_arn_suffix` | The target group |
| `web_acl_arn` | The WAF web ACL |
| `controller_policy_json` | Permissions for the controller's IRSA role |
