#!/bin/bash
set -e

echo '======================================'
echo ' k8s-observability-platform — Deploy'
echo '======================================'

: "${GRAFANA_PASSWORD:?Error: GRAFANA_PASSWORD env var is not set}"
: "${API_KEY:?Error: API_KEY env var is not set}"

if ! minikube status | grep -q 'Running'; then
  echo '[1/6] Starting Minikube...'
  minikube start --driver=docker --memory=3500 --cpus=2
else
  echo '[1/6] Minikube already running'
fi

echo '[2/6] Configuring Docker to use Minikube...'
eval $(minikube docker-env)

echo '[3/6] Building FastAPI image...'
docker build -t fastapi-app:latest ./app

echo '[4/6] Installing Prometheus...'
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring --create-namespace \
  --set server.service.type=NodePort \
  --set server.service.nodePort=30090

echo '[5/6] Installing Grafana...'
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --set service.type=NodePort \
  --set service.nodePort=30030 \
  --set adminPassword="${GRAFANA_PASSWORD}"

echo '[6/6] Deploying FastAPI via Helm...'
helm upgrade --install fastapi-release ./helm/fastapi-app \
  --set env.apiKey="${API_KEY}"

MINIKUBE_IP=$(minikube ip)
echo ''
echo '======================================'
echo ' Done!'
echo '======================================'
echo "FastAPI:    http://${MINIKUBE_IP}:30080"
echo "Prometheus: http://${MINIKUBE_IP}:30090"
echo "Grafana:    http://${MINIKUBE_IP}:30030"
echo "Grafana login: admin / [see GRAFANA_PASSWORD env var]"
