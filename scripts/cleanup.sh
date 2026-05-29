#!/bin/bash
# cleanup.sh — Tear down the full observability stack cleanly
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "======================================"
echo " k8s-observability-platform — Cleanup"
echo "======================================"
echo ""
echo -e "${YELLOW}This will remove all Helm releases and stop Minikube.${NC}"
read -rp "Are you sure? (yes/no): " confirm

if [ "${confirm}" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "[1/4] Removing FastAPI Helm release..."
helm uninstall fastapi-release --namespace default 2>/dev/null && \
  echo -e "${GREEN}  ✓ fastapi-release removed${NC}" || \
  echo "  fastapi-release not found — skipping"

echo ""
echo "[2/4] Removing Grafana Helm release..."
helm uninstall grafana --namespace monitoring 2>/dev/null && \
  echo -e "${GREEN}  ✓ grafana removed${NC}" || \
  echo "  grafana not found — skipping"

echo ""
echo "[3/4] Removing Prometheus Helm release..."
helm uninstall prometheus --namespace monitoring 2>/dev/null && \
  echo -e "${GREEN}  ✓ prometheus removed${NC}" || \
  echo "  prometheus not found — skipping"

echo ""
echo "[4/4] Stopping Minikube..."
minikube stop && \
  echo -e "${GREEN}  ✓ Minikube stopped${NC}"

echo ""
echo "======================================"
echo -e "${GREEN} Cleanup complete.${NC}"
echo " Run ./scripts/deploy.sh to redeploy."
echo "======================================"
echo ""
