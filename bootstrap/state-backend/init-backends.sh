#!/usr/bin/env bash
# Create the three per-env state buckets, then init each env's backend from the repo root.
#   ./bootstrap/state-backend/init-backends.sh            # all envs (dev qa prod)
#   ./bootstrap/state-backend/init-backends.sh dev qa     # a subset
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENVS=("$@"); [ ${#ENVS[@]} -eq 0 ] && ENVS=(dev qa prod)

echo "==> [1/2] Ensuring state buckets exist (bootstrap/state-backend, local state)"
terraform -chdir="${SCRIPT_DIR}" init  -input=false
terraform -chdir="${SCRIPT_DIR}" apply -input=false -auto-approve

echo "==> [2/2] Initializing backends for: ${ENVS[*]}"
for env in "${ENVS[@]}"; do
  backend="envs/${env}/${env}.tfbackend"
  if [ ! -f "${ROOT_DIR}/${backend}" ]; then echo "SKIP ${env}: ${backend} not found"; continue; fi
  echo "--- terraform init -reconfigure -backend-config=${backend}"
  terraform -chdir="${ROOT_DIR}" init -reconfigure -input=false -backend-config="${backend}"
done
echo "Done. Root is now initialized to '${ENVS[${#ENVS[@]}-1]}'. Use 'make plan ENV=<env>' to re-target."
