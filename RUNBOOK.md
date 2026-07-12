# Runbook — k8s-observability-platform

> Written from direct incident response experience. In biotech instrument software
> release, I was the first point of contact for production failures — field engineers,
> manufacturing, and customer complaints all came to me. These runbooks follow the same
> triage discipline: detect → isolate → mitigate → root cause → prevent.

---

## Alert: HighErrorRate (5xx > 5% for 2 minutes)

**Severity:** Warning
**PromQL:** `rate(http_requests_total{status_code=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05`

### Detection
Prometheus fires after 5xx error rate exceeds 5% for 2 continuous minutes.
Grafana Error Rate panel turns red.

### Triage
```bash
# 1. Check pod status
kubectl get pods -n default

# 2. Check recent logs
kubectl logs deployment/fastapi-release-fastapi --tail=50

# 3. Check events for errors
kubectl get events -n default --field-selector type=Warning --sort-by='.lastTimestamp'
```

### Mitigation
```bash
# If pod is crashing — restart it
kubectl rollout restart deployment/fastapi-release-fastapi

# If bad image was deployed — rollback
helm rollback fastapi-release 1

# Check rollback succeeded
kubectl rollout status deployment/fastapi-release-fastapi
```

### Root Cause
Common causes:
- Bad image pushed — check recent commits and image tag
- Dependency failure (Key Vault / Blob Storage unreachable) — check Azure status
- OOMKilled — check resource limits in values.yaml

### Prevention
- Add pre-deploy smoke test: `curl /health` before routing traffic
- Pin image tags — never deploy `:latest` in production
- Set memory limits to prevent OOM: `resources.limits.memory: 256Mi`

---

## Alert: HighLatency (p95 > 1s for 2 minutes)

**Severity:** Warning
**PromQL:** `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1`

### Detection
Prometheus fires when 95th percentile response time exceeds 1 second for 2 minutes.
Grafana Latency panel shows p95 spike.

### Triage
```bash
# Check pod resource usage
kubectl top pods -n default

# Check if node is under pressure
kubectl top nodes

# Check if CPU is being throttled
kubectl describe pod -l app=fastapi-release-fastapi | grep -A5 "Limits\|Requests"
```

### Mitigation
```bash
# If CPU throttling — scale up replicas
kubectl scale deployment fastapi-release-fastapi --replicas=2

# Or increase CPU limits in values.yaml and upgrade
helm upgrade fastapi-release ./helm/fastapi-app \
  --set resources.limits.cpu=1000m \
  --set resources.requests.cpu=200m
```

### Root Cause
Common causes:
- CPU throttling — limits too low
- Memory pressure causing GC pauses
- External dependency slow (Key Vault, Blob Storage)
- Node under resource pressure from other pods

### Prevention
- Set appropriate resource requests/limits
- Add HPA to scale pods under load
- Add timeout on external SDK calls

---

## Alert: PodNotReady (0 ready pods for 1 minute)

**Severity:** Critical
**PromQL:** `kube_pod_status_ready{condition="true"} == 0`

### Detection
Prometheus fires when no pods are in Ready state for 1 continuous minute.
This means the application is completely unavailable.

### Triage
```bash
# Immediate — check pod status
kubectl get pods -n default -o wide

# Get exact failure reason
kubectl describe pod -l app=fastapi-release-fastapi

# Check logs from crashed container
kubectl logs -l app=fastapi-release-fastapi --previous

# Check if image pull failed
kubectl get events -n default | grep -i "pull\|image\|back-off"
```

### Mitigation
```bash
# If ErrImageNeverPull (Minikube) — rebuild image
eval $(minikube docker-env)
docker build -t fastapi-app:latest ./app

# If CrashLoopBackOff — check logs then restart
kubectl logs <pod-name> --previous
kubectl rollout restart deployment/fastapi-release-fastapi

# If ImagePullBackOff (AKS) — verify ACR auth
az aks check-acr --name aks-k8s-observability \
  --resource-group rg-k8s-observability \
  --acr acrk8sobservability

# Emergency rollback
helm rollback fastapi-release 1
```

### Root Cause
Common causes:
- Bad image pushed (startup crash)
- Liveness probe misconfigured (initialDelaySeconds too low)
- OOMKilled on startup
- Image pull failure (ACR auth issue on AKS)

### Prevention
- Run `pytest` before every image build
- Set `initialDelaySeconds: 30` if app takes time to start
- Set memory limits to prevent OOM
- Monitor ACR role assignment health

---

## Alert: PrometheusTargetDown

**Severity:** Warning
**PromQL:** `up == 0`

### Detection
Prometheus fires when a scrape target returns 0 (unreachable).
Means Prometheus cannot reach the FastAPI /metrics endpoint.

### Triage
```bash
# Check if pod is running
kubectl get pods -n default

# Manually test metrics endpoint
kubectl port-forward deployment/fastapi-release-fastapi 8080:80
curl http://localhost:8080/metrics

# Check Prometheus scrape config
kubectl get configmap -n monitoring | grep prometheus
```

### Mitigation
```bash
# If pod is down — see PodNotReady runbook above

# If pod is up but metrics unreachable — check annotations
kubectl describe pod -l app=fastapi-release-fastapi | grep prometheus

# Annotations must be:
# prometheus.io/scrape: "true"
# prometheus.io/path: "/metrics"
# prometheus.io/port: "80"
```

### Root Cause
Common causes:
- Pod is down (see PodNotReady)
- prometheus.io/scrape annotation missing or wrong
- Port mismatch between annotation and actual app port
- Network policy blocking Prometheus → pod traffic

### Prevention
- Validate annotations in helm lint CI step
- Add test: `pytest` tests that /metrics returns 200

---

## Postmortem — Simulated Incident: CrashLoopBackOff After Bad Deploy

**Date:** July 2026
**Severity:** P1 — Complete service unavailability
**Duration:** ~8 minutes (simulated)
**Author:** Khine Thazin Myint (Jackie)

### What Happened
During a simulated deployment test on Minikube, a broken image
(missing dependency) was deployed. The FastAPI pod entered
CrashLoopBackOff. The PodNotReady alert fired after 1 minute.

### Timeline

| Time | Event |
|---|---|
| T+0:00 | Bad image deployed via `helm upgrade` |
| T+0:30 | Pod starts failing liveness probe at /health |
| T+1:00 | PodNotReady alert fires (Prometheus detects 0 ready pods) |
| T+1:30 | Grafana dashboard shows error rate spike to 100% |
| T+2:00 | On-call engineer detects alert |
| T+3:00 | `kubectl describe pod` confirms CrashLoopBackOff + import error in logs |
| T+5:00 | `helm rollback fastapi-release 1` executed |
| T+6:00 | Pod returns to Running/Ready |
| T+8:00 | Alert resolves. Service fully restored. |

### Root Cause
A Python import error in main.py (`ModuleNotFoundError: prometheus_fastapi_instrumentator`)
caused the FastAPI app to crash on startup. The image was built without
running `pip install -r requirements.txt` correctly.

### Detection
- PodNotReady Prometheus alert fired at T+1:00
- Grafana Error Rate panel showed 100% error rate
- `kubectl logs --previous` showed the exact Python traceback

### Mitigation
```bash
helm rollback fastapi-release 1
kubectl rollout status deployment/fastapi-release-fastapi
```

### Root Cause Analysis
The CI pipeline (`pytest`) was bypassed — image was built and pushed
manually without running tests. The missing dependency was not caught
before deployment.

### Action Items

| Action | Owner | Status |
|---|---|---|
| Never bypass CI — all images must pass pytest before push | Process | ✅ Done |
| Add startup probe with longer initialDelaySeconds | Config | ✅ Done |
| Pin all dependency versions in requirements.txt | Code | ✅ Done |
| Add pre-deploy smoke test in deploy script | Script | 📋 Planned |

### Lessons Learned
1. **CI gates must be enforced** — manual image builds that skip pytest are the #1 risk
2. **`helm rollback` is fast** — 2-minute MTTR with Helm revision history
3. **`kubectl logs --previous`** is essential — you need the crashed container's logs, not the new one's
4. **Alert `for: 1m`** on PodNotReady is the right threshold — short enough to catch outages, long enough to avoid false positives from rolling restarts

---

## Quick Reference — Diagnostic Commands

```bash
# Pod status
kubectl get pods -n default -o wide

# Describe pod (events + config)
kubectl describe pod <pod-name> -n default

# Current logs
kubectl logs <pod-name> -n default

# Logs from crashed container
kubectl logs <pod-name> -n default --previous

# Resource usage
kubectl top pods -n default
kubectl top nodes

# Events (warnings only)
kubectl get events -n default --field-selector type=Warning --sort-by='.lastTimestamp'

# Rollback
helm rollback fastapi-release 1
helm history fastapi-release

# Restart deployment
kubectl rollout restart deployment/fastapi-release-fastapi
kubectl rollout status deployment/fastapi-release-fastapi
```