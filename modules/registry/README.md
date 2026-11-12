# registry

The service's image repository in Amazon ECR, in this account.

- **Immutable tags.** A tag, once pushed, always means the same image, so a deployed tag
  traces back to one build. Pushing an existing tag again fails.
- **Scan on push.** Every pushed image is checked for known vulnerabilities.
- **Encrypted with a key of the account.** ECR holds grants on the key and calls KMS
  itself; pushing and pulling need no permission on the key.
- **Not deleted while it holds images.** `force_delete` is off.
- **One repository per account.** Copying a released image from dev to prod belongs to
  the pipeline that builds and deploys the service, which this repository does not
  provision.

## Lifecycle policy

An image that matches the tags of a rule can only be expired by that rule, but later
rules still count it.

| Priority | Selects | Expires |
|----------|---------|---------|
| 1 | Untagged images | After `untagged_expiry_days` |
| 2 | Tags matching `release_tag_patterns` (`v*`) | Beyond the newest `max_release_images` |
| 3 | Every other image, such as commit builds | Once outside the newest `max_other_images` images of any kind, releases and untagged images included |

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `name` | `string` | Repository name, for example `platform/api` |
| `untagged_expiry_days` | `number` | Default: 7 |
| `release_tag_patterns` | `list(string)` | Default: `["v*"]` |
| `max_release_images` | `number` | Default: 30 |
| `max_other_images` | `number` | Default: 20 |

## Outputs

| Name | Description |
|------|-------------|
| `repository_url` | Where images are pushed and pulled |
| `repository_arn` | The repository's ARN |
