#!/bin/bash
# cluster-status.sh — Show current state of all k8s resources in the stack
set -euo pipefail

NAMESPACE_APP="default"
NAMESPACE_MON="monitoring"

echo ""
echo "======================================"
echo " k8s-observability-platform — Cluster Status"
echo "======================================"

echo ""
echo "--- Minikube ---"
minikube status

echo ""
echo "--- Nodes ---"
kubectl get nodes -o wide

echo ""
echo "--- Pods [default] ---"
kubectl get pods -n "${NAMESPACE_APP}" -o wide

echo ""
echo "--- Pods [monitoring] ---"
kubectl get pods -n "${NAMESPACE_MON}" -o wide

echo ""
echo "--- Services [default] ---"
kubectl get svc -n "${NAMESPACE_APP}"

echo ""
echo "--- Services [monitoring] ---"
kubectl get svc -n "${NAMESPACE_MON}"

echo ""
echo "--- Helm Releases ---"
helm list --all-namespaces

echo ""
echo "--- PersistentVolumeClaims ---"
kubectl get pvc --all-namespaces

echo ""
echo "--- Events (warnings only) ---"
kubectl get events --all-namespaces --field-selector type=Warning \
  --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "No warnings found"

echo ""
echo "======================================"
echo " Access URLs"
echo "======================================"
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "127.0.0.1")
echo "  FastAPI:    http://${MINIKUBE_IP}:30080"
echo "  Prometheus: http://${MINIKUBE_IP}:30090"
echo "  Grafana:    http://${MINIKUBE_IP}:30030"
echo ""
