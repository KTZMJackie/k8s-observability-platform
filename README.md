![CI](https://github.com/KTZMJackie/k8s-observability-platform/actions/workflows/ci.yml/badge.svg)

# k8s-observability-platform

A production-style Kubernetes observability platform running locally on Minikube.
Demonstrates end-to-end container orchestration, metrics collection, and visualisation.

## Architecture

```mermaid
graph TD
    Dev[👩‍💻 Developer] -->|git push| GH[GitHub]
    GH -->|triggers| CI[GitHub Actions CI]
    CI -->|pytest 4 tests| T{Tests Pass?}
    T -->|✅ pass| HL[helm lint]
    T -->|❌ fail| BLOCK[PR Blocked]
    HL -->|✅ pass| GREEN[Green Check ✅]

    Dev -->|./scripts/deploy.sh| DS[deploy.sh]
    DS -->|eval minikube docker-env| MK[Minikube]
    DS -->|docker build| IMG[fastapi-app:latest]
    IMG -->|stored in| MKDOCKER[Minikube Docker Daemon]

    MK --> NS1[namespace: default]
    MK --> NS2[namespace: monitoring]

    NS1 --> SEC[Secret: fastapi-secret\napi-key injected via secretKeyRef]
    NS1 --> DEP[Deployment\nfastapi-release-fastapi]
    DEP --> POD[FastAPI Pod :80\nliveness + readiness /health]
    POD -->|exposes| SVC[Service NodePort :30080]

    NS2 --> PROM[Prometheus :30090\nscrapes /metrics every 15s]
    NS2 --> GRAF[Grafana :30030\n4 dashboards]

    POD -->|/metrics endpoint| PROM
    PROM -->|datasource| GRAF

    GRAF --> D1[Request Rate]
    GRAF --> D2[p50/p95 Latency]
    GRAF --> D3[Error Rate 5xx]
    GRAF --> D4[Requests by Endpoint]
```

## Tech Stack

| Layer | Tool |
|---|---|
| App | Python FastAPI + Docker |
| Orchestration | Kubernetes (Minikube) |
| Packaging | Helm 3 |
| Metrics | Prometheus |
| Dashboard | Grafana |
| Automation | Bash deploy script |
| Config management | Ansible |

## Key Features

- One-command deployment via `./scripts/deploy.sh`
- Auto-instrumented metrics via prometheus-fastapi-instrumentator
- Kubernetes liveness health probes on `/health` endpoint
- Helm chart for repeatable configurable deployments
- Grafana dashboard showing HTTP request count
- Ansible playbook for bootstrapping tool dependencies

## How to Run

Requirements: Docker Desktop, Minikube, kubectl, Helm, Ansible

```bash
git clone https://github.com/KTZMJackie/k8s-observability-platform
cd k8s-observability-platform
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

Then access via port-forward:

```bash
kubectl port-forward deployment/fastapi-release-fastapi 8080:80
```

## API Endpoints

| Endpoint | Description |
|---|---|
| GET / | Service status |
| GET /health | Health check for Kubernetes liveness probe |
| GET /metrics | Prometheus metrics endpoint |

## Screenshots

![Grafana Dashboard](screenshots/grafana-dashboard.png)

## Grafana Dashboard

Dashboard JSON is version-controlled at `grafana/fastapi-dashboard.json`.

To import:
1. Open Grafana → Dashboards → Import
2. Upload `grafana/fastapi-dashboard.json`
3. Select your Prometheus data source
4. Click Import

Panels included:
- Request Rate (req/s)
- Request Latency (p50 / p95)
- Error Rate (5xx)
- Total Requests by Endpoint

![Prometheus Targets](screenshots/prometheus-targets.png)
![Pods Running](screenshots/kubectl-pods.png)
![FastAPI Health](screenshots/fastapi-health.png)

## Author

Built as part of a hands-on DevOps/cloud engineering portfolio.
