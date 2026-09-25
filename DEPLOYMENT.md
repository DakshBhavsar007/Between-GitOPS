# Deployment & GitOps Operations Guide

This guide details the deployment architecture, release pipeline, and operational procedures for the **Between** (Vishleshan) AI Resume Intelligence Platform.

---

## 1. End-to-End GitOps Flow

Between adheres strictly to GitOps principles: Git is the single source of truth for both application source code and infrastructure manifests.

```
+------------------+         git push          +---------------------------+
| Developer Work   | ----------------------->  | GitHub Repository         |
| (Feature/Hotfix) |                           | (Between-GitOps)          |
+------------------+                           +---------------------------+
                                                             |
                                                    Triggers GitHub Actions
                                                             v
+--------------------------------------------------------------------------+
|                      CI Pipeline (.github/workflows/docker-ci.yml)       |
|                                                                          |
|   1. Quality Gate: Frontend asset build & Node.js 22 test matrix         |
|   2. Quality Gate: Python 3.11 syntax compilation & Django unit tests    |
|   3. Docker Build: Multi-platform images built via Buildx                |
|   4. Publication:  Published to GHCR with full 40-char commit SHA tags   |
|                                                                          |
|   NO cluster credentials (kubeconfig/AWS keys) exist in GitHub Actions.  |
+--------------------------------------------------------------------------+
                                                             |
                                                    Immutable SHA Image Tag
                                                             v
+--------------------------------------------------------------------------+
|                      GitOps Manifests (gitops-manifests/)                |
|                                                                          |
|   base/       -> Deployments, Services, ConfigMap, Ingress, PVC          |
|   overlays/   -> Pinned immutable commit SHAs, replica counts            |
+--------------------------------------------------------------------------+
                                                             |
                                               ArgoCD Polls / Auto-Reconciles
                                                             v
+--------------------------------------------------------------------------+
|                   Target Environment: AWS EC2 (k3s Cluster)              |
|                                                                          |
|   - ArgoCD Application Controller executes automated sync                |
|   - Traefik routes inbound HTTP/HTTPS traffic to Services                |
|   - Workloads run as non-root containers with resource limits            |
|   - Database traffic connects securely to private AWS RDS PostgreSQL     |
+--------------------------------------------------------------------------+
```

---

## 2. Secrets Management & Separation

Production credentials are **never** committed to Git.

### Separation Model
- **Manifests Repo (`gitops-manifests/`)**: Contains only non-sensitive configuration (`between-config` ConfigMap, PVCs, Services, Deployments).
- **Cluster Secret (`between-secrets`)**: Applied directly to the Kubernetes cluster out-of-band via operator credentials or sealed secrets.
- **ArgoCD Configuration**: `ignoreDifferences` is configured on `between-secrets` so that GitOps reconciliation never overwrites production secrets with placeholder templates.

### Required Cluster Secret Keys
```bash
kubectl create secret generic between-secrets -n between \
  --from-literal=DATABASE_URL="postgresql://<user>:<password>@<rds-endpoint>:5432/<dbname>" \
  --from-literal=REDIS_URL="redis://between-redis:6379/1" \
  --from-literal=JWT_SECRET="<random-32-char-secret>" \
  --from-literal=GEMINI_API_KEY="<api-key>" \
  --from-literal=TWOFACTOR_API_KEY="<api-key>" \
  --from-literal=ADMIN_EMAIL="admin@between.com" \
  --from-literal=ADMIN_PASSWORD="<admin-password>"
```

---

## 3. Deployment Strategies

Due to the single-node architecture and `ReadWriteOnce` storage constraints:

| Workload | Replicas | Strategy | Justification |
| :--- | :--- | :--- | :--- |
| `between-backend` | 1 | `Recreate` | Prevents multiple pods competing for RWO volume `between-uploads-pvc` and prevents RAM spikes on 2GB EC2 |
| `between-celery` | 1 | `Recreate` | Ensures cleanly terminated worker before new container attaches PVC; limits concurrency to solo pool |
| `between-frontend` | 1 | `RollingUpdate` (`maxSurge: 0`, `maxUnavailable: 1`) | Zero memory surge; atomic container swap |
| `between-redis` | 1 | `Recreate` | In-memory cache & task queue state |

---

## 4. Release Lifecycle (How to Deploy a New Version)

To release a new version through GitOps:

1. **Commit and Push Code Changes**:
   ```bash
   git add .
   git commit -m "feat(api): add new candidate ranking capability"
   git push origin main
   ```

2. **CI Pipeline Runs Automatically**:
   - Tests execute in GitHub Actions runner.
   - Images are published to GitHub Container Registry:
     - `ghcr.io/dakshbhavsar007/between-backend:<commit-sha>`
     - `ghcr.io/dakshbhavsar007/between-frontend:<commit-sha>`

3. **Update Image Tag in Staging Overlay**:
   In `gitops-manifests/overlays/staging/kustomization.yaml`:
   ```yaml
   images:
     - name: ghcr.io/dakshbhavsar007/between-backend
       newTag: <commit-sha>
     - name: ghcr.io/dakshbhavsar007/between-frontend
       newTag: <commit-sha>
   ```

4. **ArgoCD Automated Reconciliation**:
   - ArgoCD detects the new Git commit SHA within its polling interval (or immediately via webhook).
   - Reconciles desired state with cluster state.
   - Pods are gracefully recreated with zero configuration drift.

---

## 5. Inspection and Troubleshooting

### Verify ArgoCD Sync
```bash
kubectl get applications -n argocd
kubectl describe application between-staging -n argocd
```

### Verify Running Pods
```bash
kubectl get pods -n between -o wide
```

### Check Logs
```bash
# Backend logs
kubectl logs deployment/between-backend -n between --tail=100

# Celery task queue logs
kubectl logs deployment/between-celery -n between --tail=100

# Frontend access logs
kubectl logs deployment/between-frontend -n between --tail=50
```

### Health Check Endpoints
```bash
# Ingress healthcheck
curl -I http://<EC2-IP-OR-DOMAIN>/healthz

# Direct backend API healthcheck
curl -I http://<EC2-IP-OR-DOMAIN>/api/v1/health

# Frontend single page application
curl -I http://<EC2-IP-OR-DOMAIN>/
```
