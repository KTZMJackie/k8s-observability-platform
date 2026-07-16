#!/usr/bin/env bash
#
# deploy-aks.sh — provision AKS + ACR and deploy the FastAPI app via Helm.
# Makes the AKS deployment reproducible (not just a screenshot).
#
# Usage:
#   export RESOURCE_GROUP=rg-k8s-observability
#   ./deploy-aks.sh
#
# Requirements: az CLI (logged in via `az login`), kubectl, helm.

set -euo pipefail

# ---- Config (override via env vars) ----
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-k8s-observability}"
LOCATION="${LOCATION:-southeastasia}"
ACR_NAME="${ACR_NAME:-acrk8sobservability}"
AKS_NAME="${AKS_NAME:-aks-k8s-observability}"
NODE_COUNT="${NODE_COUNT:-1}"
NODE_SIZE="${NODE_SIZE:-Standard_B2s}"
IMAGE_NAME="${IMAGE_NAME:-fastapi-app}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
HELM_RELEASE="${HELM_RELEASE:-fastapi-release}"
HELM_CHART="${HELM_CHART:-./helm/fastapi-app}"

echo "=================================================="
echo " Deploy to AKS: $AKS_NAME ($LOCATION)"
echo "=================================================="

# ---- 1. Resource group ----
echo "[1/6] Ensuring resource group '$RESOURCE_GROUP'..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

# ---- 2. Azure Container Registry ----
echo "[2/6] Ensuring ACR '$ACR_NAME'..."
if ! az acr show --name "$ACR_NAME" --output none 2>/dev/null; then
  az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic --output none
fi

# ---- 3. AKS cluster (attached to ACR so no imagePullSecrets needed) ----
echo "[3/6] Ensuring AKS cluster '$AKS_NAME'..."
if ! az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --output none 2>/dev/null; then
  az aks create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_NAME" \
    --node-count "$NODE_COUNT" \
    --node-vm-size "$NODE_SIZE" \
    --attach-acr "$ACR_NAME" \
    --generate-ssh-keys \
    --output none
fi

# ---- 4. Build + push image in ACR (no local Docker needed) ----
echo "[4/6] Building image $IMAGE_NAME:$IMAGE_TAG in ACR..."
az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" ./app --output none

# ---- 5. Get kubeconfig ----
echo "[5/6] Fetching AKS credentials..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing

# ---- 6. Deploy via Helm with a public LoadBalancer ----
echo "[6/6] Deploying '$HELM_RELEASE' via Helm..."
helm upgrade --install "$HELM_RELEASE" "$HELM_CHART" \
  --set image.repository="${ACR_NAME}.azurecr.io/${IMAGE_NAME}" \
  --set image.tag="${IMAGE_TAG}" \
  --set service.type=LoadBalancer \
  --wait --timeout 5m

echo ""
echo "Waiting for LoadBalancer public IP..."
for i in $(seq 1 30); do
  IP=$(kubectl get svc "${HELM_RELEASE}-service" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [ -n "${IP:-}" ] && break
  sleep 10
done

echo ""
echo "=================================================="
if [ -n "${IP:-}" ]; then
  echo " Done. App live at: http://$IP"
  echo "   health: http://$IP/health"
  echo "   metrics: http://$IP/metrics"
else
  echo " Deployed, but LoadBalancer IP not ready yet."
  echo " Check: kubectl get svc ${HELM_RELEASE}-service -w"
fi
echo "=================================================="
kubectl get nodes
kubectl get pods -o wide
kubectl get svc
