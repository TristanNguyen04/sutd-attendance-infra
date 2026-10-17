.PHONY: fmt fmt-check validate lint check

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive

# Validates each stack without touching remote state.
validate:
	@for d in stacks/*/; do \
		if ls $$d*.tf >/dev/null 2>&1; then \
			echo "==> $$d"; \
			terraform -chdir=$$d init -backend=false -input=false >/dev/null && \
			terraform -chdir=$$d validate || exit 1; \
		fi; \
	done

lint:
	tflint --recursive

check: fmt-check validate lint
