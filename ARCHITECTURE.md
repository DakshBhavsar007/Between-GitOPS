# System Architecture & Technical Specifications

## Between AI Resume Intelligence Platform — Production GitOps Architecture

This document specifies the production GitOps infrastructure designed for the **Between** (Vishleshan) AI Resume Intelligence platform hosted on AWS EC2 using k3s, ArgoCD, and AWS RDS PostgreSQL.

---

## 1. Architectural Blueprint

```
+---------------------------------------------------------------------------------------------------+
|                                        DEVELOPER WORKFLOW                                         |
|                                                                                                   |
|   +--------------------+          git push          +-----------------------------------------+   |
|   | Developer Machine  | ------------------------>  | App Repo: Between-GitOps (GitHub)       |   |
|   +--------------------+                            +-----------------------------------------+   |
+---------------------------------------------------------------------------------------------------+
                                                                   |
                                                          Triggers GitHub Actions
                                                                   v
+---------------------------------------------------------------------------------------------------+
|                                      CI PIPELINE (GITHUB ACTIONS)                                 |
|                                                                                                   |
|   [Stage 1: Validate & Test]    -->   [Stage 2: Build & Push GHCR]                                |
|   - Frontend ESLint & Build            - ghcr.io/dakshbhavsar007/between-backend:<commit-sha>     |
|   - Backend PyCompile & Tests          - ghcr.io/dakshbhavsar007/between-frontend:<commit-sha>    |
|   - PostgreSQL & Redis Test Containers - Immutable 40-char SHA Tagging                            |
|                                                                                                   |
|   SECURITY RULE: NO `kubectl` in CI. Zero cluster secrets stored on GitHub runners.               |
+---------------------------------------------------------------------------------------------------+
                                                                   |
                                                      Immutable SHA Image Tag
                                                                   v
+---------------------------------------------------------------------------------------------------+
|                                   GITOPS MANIFESTS (gitops-manifests/)                            |
|                                                                                                   |
|   base/       -> Deployments, Services, ConfigMap, Ingress, PVC                                   |
|   overlays/   -> Pinned immutable commit SHAs, single-replica sizing, kustomization               |
+---------------------------------------------------------------------------------------------------+
                                                                   |
                                                ArgoCD Polls / Continuous Reconciliation
                                                                   v
+---------------------------------------------------------------------------------------------------+
|                                           AWS CLOUD (ap-south-1)                                  |
|                                                                                                   |
|   +-------------------------------------------------------------------------------------------+   |
|   | AWS EC2 Instance (t3.small / 2 GiB RAM / Ubuntu 24.04 / Dynamic Public IPv4)               |   |
|   |                                                                                           |   |
|   |   +-----------------------------------------------------------------------------------+   |   |
|   |   | k3s Lightweight Kubernetes Cluster (v1.36.4+k3s1)                                 |   |   |
|   |   |                                                                                   |   |   |
|   |   |   [ArgoCD Controller]  <--- Continuous Reconciliation (selfHeal: true, prune: true)   |   |
|   |   |                                                                                   |   |   |
|   |   |   [Traefik Ingress Controller] (Ports 80 & 443)                                    |   |   |
|   |   |       |             |                                                             |   |   |
|   |   |       v             v                                                             |   |   |
|   |   |   [Frontend Pod]  [Backend Pod] <---------> [Celery Worker Pod]                   |   |   |
|   |   |   (React NGINX)   (Django WSGI)                   |                               |   |   |
|   |   |       |                 |                         v                               |   |   |
|   |   |       |                 |                   [Redis Pod] (redis:7-alpine)          |   |   |
|   |   |       |                 |                                                         |   |   |
|   |   |       |                 +------------------+                                      |   |   |
|   |   |       v                                    v                                      |   |   |
|   |   |   [Local-Path PVC (5Gi)]            [between-secrets (Opaque)]                    |   |   |
|   |   +--------------------------------------------|--------------------------------------+   |   |
|   +------------------------------------------------|------------------------------------------+   |
|                                                    | (TCP 5432 - VPC Private Ingress)             |
|                                                    v                                              |
|   +-------------------------------------------------------------------------------------------+   |
|   | AWS RDS PostgreSQL 15.13 (db.t4g.micro / between-prod-db / Private Subnet Group)          |   |
|   | - 20 GiB gp3 storage                                                                      |   |
|   | - Security Group: sg-02e6070330f3a5524 (Restricted to k3s EC2 SG only)                    |   |
|   | - Automated Daily Backups enabled                                                         |   |
|   +-------------------------------------------------------------------------------------------+   |
+---------------------------------------------------------------------------------------------------+
```

---

## 2. Infrastructure Specifications

### Compute: AWS EC2
- **Instance Type**: `t3.small` (2 vCPUs, 2.0 GiB RAM).
- **Operating System**: Ubuntu 24.04 LTS (Kernel 7.0.0-aws).
- **Storage**: 30 GiB gp3 root EBS volume.
- **Swap**: 4 GiB swapfile enabled to provide a safety margin against burst memory allocations.
- **Kubernetes Engine**: k3s `v1.36.4+k3s1` with embedded SQLite/Kine and containerd.

### Database: AWS RDS PostgreSQL
- **Engine**: PostgreSQL 15.13.
- **Instance Class**: `db.t4g.micro` (AWS Graviton2, 2 vCPUs, 1.0 GiB RAM).
- **DB Identifier**: `between-prod-db`.
- **Public Accessibility**: `False` (strictly private).
- **Subnet Group**: Spans 3 Availability Zones (`ap-south-1a`, `ap-south-1b`, `ap-south-1c`) in VPC `vpc-0ae6efca7d7bba860`.
- **Security Group**: Ingress port 5432 allowed **only** from k3s EC2 security group (`sg-0590cd801dfc08813`).

### Networking & Security Groups

#### EC2 Security Group (`sg-0590cd801dfc08813`)
| Protocol | Port | Source | Purpose |
| :--- | :--- | :--- | :--- |
| TCP | 80 | `0.0.0.0/0` | Public HTTP traffic (Traefik) |
| TCP | 443 | `0.0.0.0/0` | Public HTTPS traffic (Traefik) |
| TCP | 22 | Operator Subnet (`152.58.0.0/16`) | Secure SSH administration |
| TCP | 6443 | Operator Subnet (`152.58.0.0/16`) | Secure Kubernetes API access |

#### RDS Security Group (`sg-02e6070330f3a5524`)
| Protocol | Port | Source | Purpose |
| :--- | :--- | :--- | :--- |
| TCP | 5432 | `sg-0590cd801dfc08813` | Internal database connections from k3s pods |

---

## 3. Workload Topology & Resource Allocations

| Deployment | Container Image | CPU Req/Lim | Mem Req/Lim | Storage / Mounts |
| :--- | :--- | :--- | :--- | :--- |
| `between-backend` | `ghcr.io/.../between-backend:<sha>` | 100m / 500m | 256Mi / 1024Mi | `/app/uploads`, `/app/photos` (PVC: `between-uploads-pvc`) |
| `between-celery` | `ghcr.io/.../between-backend:<sha>` | 100m / 500m | 256Mi / 1024Mi | `/app/uploads`, `/app/photos` (PVC: `between-uploads-pvc`) |
| `between-frontend` | `ghcr.io/.../between-frontend:<sha>` | 20m / 100m | 32Mi / 128Mi | Static bundle served by Nginx 1.27 |
| `between-redis` | `redis:7-alpine` | 50m / 200m | 64Mi / 256Mi | In-memory task queue & cache |
| `argocd-*` | `quay.io/argoproj/argocd:v2.10.x` | Minimal | ~350Mi combined | GitOps continuous reconciliation engine |
| `traefik` | `rancher/k3s:embedded-traefik` | Minimal | ~30Mi | Ingress controller routing ports 80/443 |

---

## 4. Ingress Routing Rules

Traefik evaluates incoming requests against the following routing hierarchy:

| Inbound Path | Target Service | Container Port | Protocol / Behavior |
| :--- | :--- | :--- | :--- |
| `/api/*` | `between-backend` | 8000 | Proxied to Gunicorn REST API |
| `/static/*` | `between-backend` | 8000 | Django WhiteNoise static assets |
| `/uploads/*` | `between-backend` | 8000 | Uploaded resume PDFs & documents |
| `/photos/*` | `between-backend` | 8000 | Candidate avatars & company logos |
| `/healthz` | `between-frontend` / `between-backend` | 80 / 8000 | Health probe endpoint returning HTTP 200 |
| `/*` (catch-all) | `between-frontend` | 80 | React Single Page Application (SPA) |
