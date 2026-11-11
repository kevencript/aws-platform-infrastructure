# The bootstrap stack creates what must exist in an account before the root
# module can run there, and what must outlive the environment: the storage
# for Terraform state, the public hosted zone, and the identity that GitHub
# Actions uses in this account. Each concern has its own file.
#
# The stack is applied by a person, once per account. README.md has the steps.

locals {
  # One naming scheme for the whole project: <project>-<environment>-<purpose>.
  name_prefix = "${var.project}-${var.environment}"
}
