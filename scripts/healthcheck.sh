#!/bin/bash
# healthcheck.sh — Check health of all services in the observability stack
set -euo pipefail

MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "127.0.0.1")
FASTAPI_URL="http://${MINIKUBE_IP}:30080"
PROMETHEUS_URL="http://${MINIKUBE_IP}:30090"
GRAFANA_URL="http://${MINIKUBE_IP}:30030"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_service() {
  local name=$1
  local url=$2
  local expected_status=${3:-200}

  http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${url}" 2>/dev/null || echo "000")

  if [ "${http_status}" -eq "${expected_status}" ]; then
    echo -e "${GREEN}[✓] ${name} — HTTP ${http_status}${NC}"
    return 0
  else
    echo -e "${RED}[✗] ${name} — HTTP ${http_status} (expected ${expected_status})${NC}"
    return 1
  fi
}

echo ""
echo "======================================"
echo " k8s-observability-platform — Health Check"
echo " Minikube IP: ${MINIKUBE_IP}"
echo "======================================"
echo ""

PASS=0
FAIL=0

check_service "FastAPI     root      " "${FASTAPI_URL}/"          200 && ((PASS++)) || ((FAIL++))
check_service "FastAPI     /health   " "${FASTAPI_URL}/health"    200 && ((PASS++)) || ((FAIL++))
check_service "FastAPI     /metrics  " "${FASTAPI_URL}/metrics"   200 && ((PASS++)) || ((FAIL++))
check_service "Prometheus  /-/ready  " "${PROMETHEUS_URL}/-/ready" 200 && ((PASS++)) || ((FAIL++))
check_service "Grafana     /api/health" "${GRAFANA_URL}/api/health" 200 && ((PASS++)) || ((FAIL++))

echo ""
echo "======================================"
echo -e " Results: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}"
echo "======================================"
echo ""

if [ "${FAIL}" -gt 0 ]; then
  echo -e "${YELLOW}Tip: Run ./scripts/deploy.sh to restart the stack${NC}"
  exit 1
fi

exit 0
