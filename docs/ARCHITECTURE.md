# System Architecture & Technical Specifications

## Between AI Resume Intelligence Platform - GitOps Architecture

This document details the production GitOps infrastructure designed for the **Between** (Vishleshan) AI Resume Intelligence platform hosted on AWS EC2 using k3s and ArgoCD.

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
|   [Stage 1: Lint & Tests]  -->  [Stage 2: Build & Push GHCR]  -->  [Stage 3: GitOps Tag Update]    |
|   - Frontend ESLint & Build      - ghcr.io/.../between-backend     - Clones Manifests Repo        |
|   - Backend PyCompile & Tests    - ghcr.io/.../between-frontend    - kustomize edit set image     |
|                                                                    - git commit & git push        |
|                                                                                                   |
|   CRITICAL: NO `kubectl apply` in CI! ZERO cluster credentials stored in GitHub runners!         |
+---------------------------------------------------------------------------------------------------+
                                                                   |
                                                          Pushes New Tag Commit
                                                                   v
+---------------------------------------------------------------------------------------------------+
|                                   GITOPS REPOSITORY (SINGLE SOURCE OF TRUTH)                       |
|                                                                                                   |
|   Between-GitOps-Manifests (GitHub Repository)                                                    |
|   ├── base/ (Deployments, Services, ConfigMaps, Secrets, Ingress, PVC)                             |
|   └── overlays/prod/kustomization.yaml  <-- Pinned image tag updated by CI                        |
+---------------------------------------------------------------------------------------------------+
                                                                   |
                                              ArgoCD polls or receives webhook
                                                                   v
+---------------------------------------------------------------------------------------------------+
|                                           AWS CLOUD (ap-south-1)                                  |
|                                                                                                   |
|   +-------------------------------------------------------------------------------------------+   |
|   | AWS EC2 Instance (t3.medium / Ubuntu 24.04 / Elastic IP)                                  |   |
|   |                                                                                           |   |
|   |   +-----------------------------------------------------------------------------------+   |   |
|   |   | k3s Lightweight Kubernetes Cluster                                                |   |   |
|   |   |                                                                                   |   |   |
|   |   |   [ArgoCD Controller]  <--- Continuous Reconciliation (selfHeal: true, prune: true)   |   |
|   |   |                                                                                   |   |   |
|   |   |   [Traefik Ingress Controller] (Ports 80 & 443)                                    |   |   |
|   |   |       |             |                                                             |   |   |
|   |   |       v             v                                                             |   |   |
|   |   |   [Frontend Pods] [Backend Pods] <---------> [Celery Worker Pods]                 |   |   |
|   |   |   (React NGINX)   (Django WSGI)                   |                               |   |   |
|   |   |                         |                         |                               |   |   |
|   |   |                         +-----------+-------------+                               |   |   |
|   |   |                                     |                                             |   |   |
|   |   |                                     v                                             |   |   |
|   |   |                             [Redis Pod (Broker)]                                  |   |   |
|   |   |                                                                                   |   |   |
|   |   |                             [local-path PVC: Uploads & Photos]                    |   |   |
|   |   +-----------------------------------------------------------------------------------+   |   |
|   +-------------------------------------------------------------------------------------------+   |
|                                                 | (TCP Port 5432)                                 |
|                                                 v                                                 |
|   +-------------------------------------------------------------------------------------------+   |
|   | AWS RDS PostgreSQL (db.t4g.micro / Engine 15 / VPC Security Group Restricted)              |   |
|   +-------------------------------------------------------------------------------------------+   |
+---------------------------------------------------------------------------------------------------+
```

---

## 2. Core Components & Responsibilities

| Component | Technology | Role |
| :--- | :--- | :--- |
| **Backend API** | Django 5.x + Gunicorn | Serves REST APIs, authentication, admin dashboard, and file parsing. |
| **Worker Engine** | Celery 5.4 + Redis 7 | Asynchronously parses resume files, processes background LLM enrichment, and syncs candidate pipelines. |
| **Frontend** | React 18 + Vite 5 + NGINX | SPA interface with client-side routing and reverse proxy for zero-CORS configuration. |
| **Container Engine** | Docker Multi-Stage | Lean Alpine/Slim runtime containers running as non-root users (`UID 1000`). |
| **Container Registry**| GitHub Packages (GHCR) | Stores versioned container images tagged with immutable Git commit SHAs. |
| **Kubernetes Engine**| k3s | Ultra-lightweight Kubernetes distribution engineered for edge and single/multi-node cloud instances. |
| **Continuous Delivery**| ArgoCD | Declarative GitOps engine pulling from Git and maintaining cluster state without inbound ports. |
| **Database** | AWS RDS PostgreSQL | Fully managed relational database with automated backups and private VPC peering. |

---

## 3. Security Architecture

1. **Least-Privilege CI/CD**:
   - The GitHub Actions CI runner does **NOT** possess AWS access keys or Kubernetes `kubeconfig` files.
   - If CI is compromised, attackers cannot access the live production cluster.
2. **Pull Model vs Push Model**:
   - Standard CI/CD "pushes" changes by giving the CI runner root-level cluster credentials.
   - GitOps "pulls" changes: ArgoCD resides *inside* the cluster and queries Git outbound via HTTPS. No Kubernetes API ports (6443) need to be open to the public internet!
3. **Container Hardening**:
   - Both backend and frontend containers run as unprivileged non-root users.
   - Multi-stage builds strip compilers, headers, and build tools from the final production images.
4. **Database Isolation**:
   - The AWS RDS PostgreSQL instance does not have a public IP.
   - Inbound TCP 5432 is strictly limited to the `between-k3s-sg` security group of the EC2 instance.
