#!/usr/bin/env bash
# lib.sh — shared helpers. Source this from every script:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# It locates the repo root, loads project.conf, and exposes naming conventions
# so no script hardcodes a prefix, region, or bucket name.

# Resolve paths relative to this file (works regardless of caller's cwd).
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${LIB_DIR}/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/project.conf"

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "ERROR: ${CONFIG_FILE} not found. Copy/edit project.conf first." >&2
  exit 1
fi

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

: "${PREFIX:?PREFIX must be set in project.conf}"
: "${AWS_REGION:?AWS_REGION must be set in project.conf}"
: "${ENVIRONMENTS:?ENVIRONMENTS must be set in project.conf}"

# ── Naming conventions (must match the Terraform locals) ──────────────────────
bucket_name()  { echo "${PREFIX}-s3-${1}"; }        # state bucket for env $1
cluster_name() { echo "${PREFIX}-eks-${1}"; }       # EKS cluster for env $1

# ENVIRONMENTS as an HCL list literal, e.g. ["dev","qa","prod"] — for -var.
environments_hcl() {
  local out="" e
  for e in "${ENVIRONMENTS[@]}"; do out="${out:+${out},}\"${e}\""; done
  echo "[${out}]"
}

# Terraform -var flags shared by both bootstrap stacks.
bootstrap_tf_vars() {
  echo "-var=prefix=${PREFIX}" \
       "-var=aws_region=${AWS_REGION}" \
       "-var=environments=$(environments_hcl)"
}

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' is required but not installed." >&2; exit 1; }
}

confirm() {
  # confirm "<prompt>" ; honours FORCE=true to skip.
  [ "${FORCE:-false}" = "true" ] && return 0
  local reply
  read -r -p "$1 " reply
  [ "${reply}" = "yes" ]
}
