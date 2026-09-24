# Between GitOps Manifests Repository (`between-k8s-manifests`)

This repository is the **Single Source of Truth** for all Kubernetes workloads deployed to the k3s cluster for the **Between** AI Resume Intelligence platform.

## Architecture

- **Cluster**: k3s (Lightweight CNCF-certified Kubernetes) on AWS EC2
- **Database**: AWS RDS PostgreSQL 15 (external managed database, zero in-cluster DB state)
- **Cache/Broker**: Redis 7 ClusterIP
- **CD Controller**: ArgoCD
- **Pattern**: GitOps Pull-Based Reconciliation
- **Manifest Engine**: Kustomize

## Repository Structure

```text
.
├── base/
│   ├── namespace.yaml           # Dedicated 'between' namespace
│   ├── configmap.yaml           # Non-sensitive runtime variables
│   ├── secrets-template.yaml    # Safe template for RDS & JWT credentials (REPLACE_ME)
│   ├── pvc.yaml                 # Persistent storage for uploads/photos
│   ├── redis-deployment.yaml    # Internal Redis broker deployment
│   ├── redis-service.yaml       # Internal Redis ClusterIP (between-redis:6379)
│   ├── backend-deployment.yaml  # Django API (ghcr.io/.../between-backend)
│   ├── backend-service.yaml     # Internal API ClusterIP (between-backend:8000)
│   ├── celery-deployment.yaml   # Background worker (reuses between-backend image)
│   ├── frontend-deployment.yaml # NGINX React SPA (ghcr.io/.../between-frontend)
│   ├── frontend-service.yaml    # Frontend ClusterIP (between-frontend:80)
│   ├── ingress.yaml             # Traefik routing: /api to backend, / to frontend
│   └── kustomization.yaml       # Base assembly
└── overlays/
    ├── staging/
    │   └── kustomization.yaml   # Staging image tags & overlay patches
    └── prod/
        └── kustomization.yaml   # Production image tags & overlay patches
```

## Immutable Image References

All Deployments use immutable tags published from GitHub Actions to GHCR:
- `ghcr.io/dakshbhavsar007/between-backend:<commit-sha>`
- `ghcr.io/dakshbhavsar007/between-frontend:<commit-sha>`

*(Celery directly reuses the backend container image with custom worker command).*

## Two-Repository GitOps Model

1. **Application Repository** (`Between-GitOPS`):
   Contains source code, unit tests, Dockerfiles, and GitHub Actions CI.
2. **Manifests Repository** (`between-k8s-manifests`):
   Contains solely the Kubernetes manifests above. ArgoCD continuously monitors this repository and reconciles any drift.
