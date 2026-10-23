#!/usr/bin/env bash
# configure.sh — (re)generate the per-env backend & tfvars files from project.conf.
#
# Run this after editing project.conf. It is idempotent: committed env files
# are fully derived, so changing the owner/region/sizing is a one-file edit.
#
#   ./scripts/configure.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "==> Generating env files from project.conf (PREFIX=${PREFIX}, REGION=${AWS_REGION})"

for env in "${ENVIRONMENTS[@]}"; do
  sizing_var="ENV_${env}"
  sizing="${!sizing_var:-}"
  if [ -z "${sizing}" ]; then
    echo "ERROR: no sizing defined for '${env}' (expected ${sizing_var} in project.conf)" >&2
    exit 1
  fi
  IFS='|' read -r instance_types capacity node_min node_max node_desired <<<"${sizing}"

  env_dir="${ROOT_DIR}/envs/${env}"
  mkdir -p "${env_dir}"

  # ── backend config (pure identity — safe to fully generate) ────────────────
  cat >"${env_dir}/${env}.tfbackend" <<EOF
bucket       = "$(bucket_name "${env}")"
key          = "${env}/terraform.tfstate"
region       = "${AWS_REGION}"
encrypt      = true
use_lockfile = true
EOF

  # ── tfvars (identity + per-env sizing) ─────────────────────────────────────
  # NOTE: prefix, owner, app_name are deliberately NOT written here. They are
  # injected as TF_VAR_* — from GitHub secrets in CI, and exported by the
  # Makefile (from project.conf) locally — so identity never lives in a file.
  cat >"${env_dir}/${env}.tfvars" <<EOF
environment    = "${env}"
rsrc           = "${RSRC}"
aws_region     = "${AWS_REGION}"
eks_version    = "${EKS_VERSION}"
subnet_cidrs   = ${SUBNET_CIDRS}
instance_types = ${instance_types}
capacity_type  = "${capacity}"
node_min       = ${node_min}
node_max       = ${node_max}
node_desired   = ${node_desired}
EOF

  echo "    ✓ envs/${env}/ (bucket=$(bucket_name "${env}"), cluster=$(cluster_name "${env}"))"
done

echo "==> Done. Review 'git diff envs/' and commit."
