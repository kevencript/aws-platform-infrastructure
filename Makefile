# Local quality gate. No target needs an AWS account or AWS credentials.
#
#   make check                            run every check below, in order
#   make check TERRAFORM_MIN=<binary>     also run validate and environments on the
#                                         oldest supported Terraform
#
#   make fmt            formatting of .tf, .tfvars and backend.hcl files
#   make validate       terraform validate of the root module and of bootstrap/
#   make environments   the files under environments/ against the code
#   make scan           trivy misconfiguration scan
#
#   make lock           rewrite the provider lock files (downloads from the registry)

TERRAFORM     ?= terraform
TERRAFORM_MIN ?=
TRIVY         ?= trivy

# The two Terraform configurations of this repository.
STACKS := . bootstrap

# Platforms the lock files carry hashes for: Linux runners and macOS laptops.
LOCK_PLATFORMS := linux_amd64 linux_arm64 darwin_amd64 darwin_arm64

.PHONY: check fmt validate validate-min environments scan lock

check: fmt validate validate-min environments scan

# terraform fmt skips .hcl files, so each backend file goes through standard input.
fmt:
	$(TERRAFORM) fmt -check -recursive -diff
	@for file in environments/*/backend.hcl; do \
		$(TERRAFORM) fmt -check - < $$file > /dev/null || { echo "$$file is not formatted"; exit 1; }; \
	done

# -backend=false: no state is needed to validate. -lockfile=readonly: the gate
# must use the committed provider version, never pick another one.
validate:
	@for stack in $(STACKS); do \
		echo "validate $$stack with $$($(TERRAFORM) version | head -n 1)"; \
		$(TERRAFORM) -chdir=$$stack init -backend=false -input=false -lockfile=readonly > /dev/null || exit 1; \
		$(TERRAFORM) -chdir=$$stack validate || exit 1; \
	done

# Proves the version floor in versions.tf: validate and the environment check
# run again with the older binary, so validation rules are also evaluated
# with real values on it. The binary is given on the command line because an
# older Terraform is not on the PATH under a fixed name.
validate-min:
ifdef TERRAFORM_MIN
	@$(MAKE) --no-print-directory validate environments TERRAFORM=$(TERRAFORM_MIN)
else
	@echo "validate-min: SKIPPED. Set TERRAFORM_MIN to a Terraform 1.5 binary to check the version floor."
endif

environments:
	@TERRAFORM=$(TERRAFORM) sh tools/check-environments.sh

# trivy takes one set of variable values per run, so the scan runs once per
# environment: a value in a variable file can change a finding. --exit-code 1
# fails on any finding, at any severity. Accepted findings are ignored next to
# the resource, with the reason. The skipped directory is written by the
# environments target. By default trivy fetches updates of its checks; set
# TRIVY_SKIP_CHECK_UPDATE=true to run offline with the checks it already has.
scan:
	@for env in $(notdir $(wildcard environments/*)); do \
		echo "scan with the values of $$env"; \
		$(TRIVY) config --exit-code 1 --skip-dirs .environment-check \
			--tf-vars environments/$$env/terraform.tfvars \
			--tf-vars environments/$$env/bootstrap.tfvars . || exit 1; \
	done

lock:
	@for stack in $(STACKS); do \
		$(TERRAFORM) -chdir=$$stack providers lock $(addprefix -platform=,$(LOCK_PLATFORMS)) || exit 1; \
	done
