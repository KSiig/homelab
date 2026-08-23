# Homelab — Terraform operations
#
# Usage
#   make init                       Initialize backend
#   make plan                       Plan changes
#   make plan PLAN_FILE=tfplan      Plan and save to file (used by CI)
#   make apply                      Apply (interactive confirm)
#   make apply PLAN_FILE=tfplan     Apply a saved plan file (used by CI)
#   make apply AUTO_APPROVE=1       Apply with -auto-approve
#   make fmt                        Format all .tf files
#   make validate                   Validate config
#   make shell                      Drop into subshell with creds loaded
#
# Authentication: uses GCP Application Default Credentials.
# ADC is checked automatically before any target that needs it.
# If missing or expired, launches `gcloud auth application-default login`.

AUTO_APPROVE ?= 0
PLAN_FILE    ?=

APPLY_FLAGS = $(if $(filter 1,$(AUTO_APPROVE)),-auto-approve)

ENSURE_ADC := \
	if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then \
		echo "GCP credentials missing or expired. Launching login..."; \
		gcloud auth application-default login; \
	fi

.DEFAULT_GOAL := help
.PHONY: help init fmt validate plan apply refresh shell

help:
	@echo "Homelab terraform Makefile"
	@echo
	@echo "Targets:"
	@echo "  make init                      Initialize backend"
	@echo "  make fmt                       Format all .tf files"
	@echo "  make validate                  Validate config"
	@echo "  make plan                      Plan changes"
	@echo "    make plan PLAN_FILE=tfplan    Plan and save to file (CI)"
	@echo "  make apply                     Apply changes"
	@echo "    make apply PLAN_FILE=tfplan   Apply a saved plan file (CI)"
	@echo "    make apply AUTO_APPROVE=1    Apply with -auto-approve"
	@echo "  make refresh                   Refresh state from real-world"
	@echo "  make shell                     Subshell with TF_VAR_* loaded"

init:
	@$(ENSURE_ADC)
	terraform init

fmt:
	terraform fmt -recursive

validate:
	terraform validate

plan:
	@$(ENSURE_ADC)
	terraform plan $(if $(PLAN_FILE),-out=$(PLAN_FILE))

apply:
	@$(ENSURE_ADC)
	$(if $(PLAN_FILE),terraform apply $(PLAN_FILE),terraform apply $(APPLY_FLAGS))

refresh:
	@$(ENSURE_ADC)
	terraform apply -refresh-only -auto-approve

shell:
	@$(ENSURE_ADC)
	@echo "Entering subshell. Type 'exit' to leave."
	@exec $${SHELL:-/bin/sh}
