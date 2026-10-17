.PHONY: fmt fmt-check validate lint check

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive

# Validates each stack without touching remote state. A separate TF_DATA_DIR keeps this independent
# of the real `terraform init` (whose stored S3 backend would otherwise need AWS credentials).
validate:
	@for d in stacks/*/; do \
		if ls $$d*.tf >/dev/null 2>&1; then \
			echo "==> $$d"; \
			TF_DATA_DIR=.terraform-check terraform -chdir=$$d init -backend=false -input=false >/dev/null && \
			TF_DATA_DIR=.terraform-check terraform -chdir=$$d validate || exit 1; \
		fi; \
	done

lint:
	tflint --recursive

check: fmt-check validate lint
