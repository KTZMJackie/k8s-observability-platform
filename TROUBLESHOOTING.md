# Troubleshooting Guide

## Pod stuck in CrashLoopBackOff

Run these in order:
    kubectl describe pod <pod-name> -n default
    kubectl logs <pod-name> -n default
    kubectl logs <pod-name> -n default --previous

Common causes:
- initialDelaySeconds too low — FastAPI not ready before liveness probe fires
- Fix: increase initialDelaySeconds to 30 in values.yaml

---

## ErrImageNeverPull

You forgot to run eval $(minikube docker-env) before docker build.

    eval $(minikube docker-env)
    docker build -t fastapi-app:latest ./app
    helm upgrade --install fastapi-release ./helm/fastapi-app

---

## Prometheus not scraping FastAPI

Check pod annotations:
    kubectl describe pod <fastapi-pod> | grep prometheus

Expected:
    prometheus.io/scrape: true
    prometheus.io/path: /metrics
    prometheus.io/port: 80

If missing — restart the pod:
    kubectl rollout restart deployment fastapi-release-fastapi

---

## Grafana shows No Data

1. Confirm Prometheus is running: http://$(minikube ip):30090
2. Check targets: http://$(minikube ip):30090/targets
3. FastAPI pod must show as UP
4. Confirm datasource URL: http://prometheus-server.monitoring.svc.cluster.local:80

---

## Service has no endpoints (connection refused)

    kubectl describe svc fastapi-release-service
    kubectl get pods --show-labels

Selector in Service must exactly match pod labels.
Expected: app=fastapi-release-fastapi

---

## Helm release stuck in failed state

    helm list --all-namespaces
    helm uninstall fastapi-release --namespace default
    helm upgrade --install fastapi-release ./helm/fastapi-app --set env.apiKey=$API_KEY

---

## Full stack teardown and redeploy

    ./scripts/cleanup.sh
    ./scripts/deploy.sh
