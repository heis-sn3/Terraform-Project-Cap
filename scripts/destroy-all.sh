#!/usr/bin/env bash
# Destroy all infrastructure across all environments
# Usage: ./scripts/destroy-all.sh [--force]
#
# WARNING: This will destroy ALL EKS clusters and associated resources!
# State buckets are protected and must be manually destroyed.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE=false

if [ "${1:-}" = "--force" ]; then
  FORCE=true
fi

echo "========================================================================"
echo "  DESTROY ALL ENVIRONMENTS"
echo "========================================================================"
echo ""
echo "⚠️  WARNING: This will destroy:"
echo "  • EKS cluster: ntombela-sva-eks-dev"
echo "  • EKS cluster: ntombela-sva-eks-qa"
echo "  • EKS cluster: ntombela-sva-eks-prod"
echo "  • All associated node groups, IAM roles, and security groups"
echo ""
echo "State buckets (ntombela-sva-s3-*) will NOT be destroyed (protected)."
echo ""

if [ "${FORCE}" = false ]; then
  read -p "Type 'yes' to confirm destruction: " confirmation
  if [ "${confirmation}" != "yes" ]; then
    echo "Aborted."
    exit 1
  fi
fi

for env in dev qa prod; do
  echo ""
  echo "==> Destroying ${env} environment..."
  cd "${ROOT_DIR}"
  make destroy ENV="${env}" || {
    echo "    ⚠️  ${env} destroy failed or partially completed"
  }
done

echo ""
echo "========================================================================"
echo "  Destruction complete"
echo "========================================================================"
echo ""
echo "State buckets still exist (force_destroy=false)."
echo "To remove them: empty the buckets, then run 'make destroy-state'."
echo ""
