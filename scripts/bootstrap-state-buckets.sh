#!/usr/bin/env bash
# Bootstrap script: Create the three S3 state buckets and initialize all env backends
# Usage: ./scripts/bootstrap-state-buckets.sh [dev|qa|prod...]
#
# This script:
# 1. Creates a hidden .state-bootstrap/ directory to store the bootstrap's local state
# 2. Applies bootstrap/state-backend to create the 3 S3 buckets
# 3. Initializes the main project's backends for specified environments (or all if none given)

set -euo pipefail

# Source lib.sh: sets ROOT_DIR, loads project.conf, and exposes the naming
# helpers + bootstrap_tf_vars so nothing here is hardcoded.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
BOOTSTRAP_DIR="${ROOT_DIR}/bootstrap/state-backend"
HIDDEN_STATE_DIR="${ROOT_DIR}/.state-bootstrap"

# Environments to initialize (default: all, from project.conf)
ENVS=("$@")
[ ${#ENVS[@]} -eq 0 ] && ENVS=("${ENVIRONMENTS[@]}")

echo "========================================================================"
echo "  State Bucket Bootstrap"
echo "========================================================================"
echo ""
echo "This script will:"
echo "  1. Create hidden directory: .state-bootstrap/"
echo "  2. Create S3 state buckets:"
for e in "${ENVIRONMENTS[@]}"; do echo "       • $(bucket_name "$e")"; done
echo "  3. Initialize backends for: ${ENVS[*]}"
echo ""

# Create hidden directory for bootstrap state
if [ ! -d "${HIDDEN_STATE_DIR}" ]; then
  echo "==> Creating hidden state directory: .state-bootstrap/"
  mkdir -p "${HIDDEN_STATE_DIR}"

  # Add to .gitignore if not already there
  if [ -f "${ROOT_DIR}/.gitignore" ] && ! grep -q "^\.state-bootstrap/$" "${ROOT_DIR}/.gitignore" 2>/dev/null; then
    echo ".state-bootstrap/" >> "${ROOT_DIR}/.gitignore"
    echo "    Added .state-bootstrap/ to .gitignore"
  fi
fi

echo ""
echo "==> [1/3] Initializing bootstrap (local state in .state-bootstrap/)"
terraform -chdir="${BOOTSTRAP_DIR}" init -input=false

echo ""
echo "==> [2/3] Creating S3 state buckets (this may take 30-60 seconds)"
terraform -chdir="${BOOTSTRAP_DIR}" apply -input=false -auto-approve \
  $(bootstrap_tf_vars) \
  -state="${HIDDEN_STATE_DIR}/terraform.tfstate" \
  -state-out="${HIDDEN_STATE_DIR}/terraform.tfstate"

echo ""
echo "==> [3/3] Initializing project backends for: ${ENVS[*]}"
for env in "${ENVS[@]}"; do
  backend="envs/${env}/${env}.tfbackend"
  if [ ! -f "${ROOT_DIR}/${backend}" ]; then
    echo "    SKIP ${env}: ${backend} not found"
    continue
  fi
  echo "    Configuring ${env} backend..."
  terraform -chdir="${ROOT_DIR}" init -reconfigure -input=false -backend-config="${backend}"
done

echo ""
echo "========================================================================"
echo "  ✓ Bootstrap complete!"
echo "========================================================================"
echo ""
echo "State buckets created:"
for e in "${ENVIRONMENTS[@]}"; do echo "  • $(bucket_name "$e")"; done
echo ""
echo "Bootstrap state stored in: .state-bootstrap/terraform.tfstate"
echo "Current backend initialized to: ${ENVS[${#ENVS[@]}-1]}"
echo ""
echo "Next steps:"
for e in "${ENVS[@]}"; do echo "  make plan ENV=${e}     # Verify ${e} plan"; done
echo ""
