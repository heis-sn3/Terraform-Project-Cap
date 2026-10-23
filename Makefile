# Usage: make <target> ENV=<dev|qa|prod>   (ENV defaults to dev)
#
# One-time, per-repo setup (no ENV needed):
#   make configure     regenerate envs/*/ from project.conf
#   make bootstrap      create the S3 state buckets + init all backends
#
# Day-to-day (per environment):
#   make plan ENV=dev   make apply ENV=qa   make destroy ENV=prod
ENV ?= dev
VALID_ENVS := dev qa prod
ifeq ($(filter $(ENV),$(VALID_ENVS)),)
$(error ENV must be one of: $(VALID_ENVS); got '$(ENV)')
endif

TF         := terraform
BACKEND    := envs/$(ENV)/$(ENV).tfbackend
VARFILES   := $(foreach f,$(wildcard envs/$(ENV)/*.tfvars),-var-file=$(f))
STATE_DIR  := bootstrap/state-backend
STATE_FILE := .state-bootstrap/terraform.tfstate

# Isolate each env's .terraform/ (providers + backend pointer) so environments
# never clobber each other and can run concurrently, e.g.:
#   make apply ENV=qa & make apply ENV=prod
TF_DATA_DIR ?= .terraform-$(ENV)
export TF_DATA_DIR

# Identity (prefix/owner/app_name) is injected as TF_VAR_*, never read from a
# tfvars file. Locally these are sourced from project.conf and exported below;
# in CI they come from GitHub secrets. The ?= means an already-set environment
# value (e.g. a CI secret) wins over the project.conf value.
conf          = $(shell bash -c 'source ./project.conf; printf "%s" "$$$(1)"')
TF_VAR_prefix   ?= $(call conf,PREFIX)
TF_VAR_owner    ?= $(call conf,OWNER)
TF_VAR_app_name ?= $(call conf,APP_NAME)
export TF_VAR_prefix TF_VAR_owner TF_VAR_app_name

.PHONY: help configure bootstrap fmt validate init plan apply destroy output \
        destroy-all destroy-state clean

help: ## Show this help
	@echo "Usage: make <target> ENV=<dev|qa|prod>   (default ENV=$(ENV))"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# ── One-time setup ────────────────────────────────────────────────────────────
configure: ## Regenerate envs/*/ backend+tfvars from project.conf
	./scripts/configure.sh

bootstrap: ## Create S3 state buckets + init all env backends (run once)
	./scripts/bootstrap-state-buckets.sh

# ── Validation (no AWS/backend needed) ─────────────────────────────────────────
fmt: ## Format all .tf files
	$(TF) fmt -recursive

validate: ## Validate config without a backend
	$(TF) init -backend=false
	$(TF) validate

# ── Per-environment lifecycle ──────────────────────────────────────────────────
init: ## Init the backend for ENV
	$(TF) init -reconfigure -backend-config=$(BACKEND)

plan: init ## Plan changes for ENV
	$(TF) plan $(VARFILES) -out=tfplan

apply: init ## Apply changes for ENV
	$(TF) apply $(VARFILES) -auto-approve

destroy: init ## Destroy infrastructure for ENV
	$(TF) destroy $(VARFILES) -auto-approve

output: ## Show outputs for the current backend
	$(TF) output

# ── Teardown ────────────────────────────────────────────────────────────────────
destroy-all: ## Destroy clusters in ALL envs (keeps state buckets)
	./scripts/destroy-all.sh

destroy-state: ## Destroy the S3 state buckets (run after destroy-all; empty them first)
	TF_DATA_DIR=.terraform $(TF) -chdir=$(STATE_DIR) init -input=false
	TF_DATA_DIR=.terraform $(TF) -chdir=$(STATE_DIR) destroy -auto-approve -state=../../$(STATE_FILE) \
	  $$(. scripts/lib.sh && bootstrap_tf_vars)

clean: ## Remove .terraform/ and plan files
	rm -rf .terraform .terraform-* tfplan plan_output.txt
