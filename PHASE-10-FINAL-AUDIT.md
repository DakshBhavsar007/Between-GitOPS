# PHASE 10 — FINAL PRODUCTION AUDIT

---

## Executive Summary

Phase 10 represents the final, comprehensive production engineering audit and release verification of the **Between (Vishleshan)** AI Resume Intelligence Platform.

Every critical system component has been inspected and verified against the live AWS cloud infrastructure, k3s Kubernetes cluster, ArgoCD continuous delivery engine, GitHub Actions CI runners, GitHub Container Registry, AWS Route 53 DNS, and public edge endpoints.

- **Production Domain**: `https://between.dakshaws.sryze.cc`
- **Current Git Commit SHA**: `2566eea523c0a1e1fbb991f22002b017c3f09c13`
- **Overall Result**: **PHASE 10 — PASS**

---

## Production Availability

**STATUS: PASS**

The application was tested live from external networks across all public routing tiers:

| Target Endpoint | Protocol | Observed Status | Latency | Verification Details |
| :--- | :--- | :--- | :--- | :--- |
| `http://between.dakshaws.sryze.cc/` | HTTP/1.1 | `301 Moved Permanently` | ~0.52s | Permanent redirect to `https://between.dakshaws.sryze.cc/` |
| `https://between.dakshaws.sryze.cc/` | HTTPS/TLS | `200 OK` | ~0.48s | React Single Page Application (SPA), title: *Between \| AI-Powered Recruiting & Resume Platform* |
| `https://between.dakshaws.sryze.cc/healthz` | HTTPS/TLS | `200 OK` | ~0.61s | Ingress / Nginx edge health probe |
| `https://between.dakshaws.sryze.cc/api/v1/health` | HTTPS/TLS | `200 OK` | ~0.20s | JSON: `{"status": "healthy", "service": "Between AI Engine API", "timestamp": "..."}` |
| `https://between.dakshaws.sryze.cc/api/v1/dynamic-data` | HTTPS/TLS | `200 OK` | ~0.35s | DB-backed dynamic plans, locations, and documentation templates queried from RDS PostgreSQL via Django ORM and Redis cache |

---

## GitOps Verification

**STATUS: PASS**

The end-to-end GitOps flow from Git commit to Kubernetes cluster state was audited and verified:

```text
GitHub main (2566eea)
       ↓
GitHub Actions (Workflow 36100024797)
       ↓
GHCR (ghcr.io/dakshbhavsar007/between-*:2566eea...)
       ↓
GitOps Manifests (gitops-manifests/overlays/staging)
       ↓
ArgoCD (between-staging)
       ↓
k3s Cluster on AWS EC2
```

- **Branch Synchronization**: Local `main` branch is in exact parity with remote `origin/main` (`https://github.com/DakshBhavsar007/Between-GitOPS.git`).
- **Working Tree**: Clean, zero untracked files or unstaged changes.
- **Artifact Tagging**: Pinned to immutable 40-character Git commit SHAs. No deployment uses the mutable `:latest` tag.
- **Cluster Secret Decoupling**: Production secrets exist exclusively inside the cluster as Kubernetes Opaque Secrets (`between-secrets`). Secret templates are omitted from Kustomize tracking, and ArgoCD `ignoreDifferences` prevents reconciliation overwrites.

---

## GitHub Actions / GHCR

**STATUS: PASS**

- **Workflow Name**: `Docker CI & GHCR Publishing` ([docker-ci.yml](.github/workflows/docker-ci.yml))
- **Latest Trigger Commit**: `2566eea523c0a1e1fbb991f22002b017c3f09c13`
- **Run ID**: `36100024797`
- **Overall Conclusion**: `success`
- **Job Breakdown**:
  - `Validate & Test`: **`success`** (Node 22 Vite build, Python 3.11 syntax validation, Django unit tests against PostgreSQL 15 & Redis 7 service containers).
  - `Build & Publish Containers to GHCR`: **`success`** (Docker Buildx multi-stage image creation, pushed to GitHub Container Registry).
- **Direct Cluster Access in CI**: **None**. CI workflow contains no AWS keys, SSH keys, or Kubernetes credentials.

---

## Kubernetes

**STATUS: PASS**

The k3s cluster is running stably on the single-node EC2 instance:

```text
NAME               STATUS   ROLES           AGE   VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION
ip-172-31-10-126   Ready    control-plane   12h   v1.36.4+k3s1   172.31.10.126   <none>        Ubuntu 24.04.5 LTS   7.0.0-1013-aws (amd64)
```

### Namespace Workloads (`between`)
- `between-backend-86b9d8dfcc-6v2pv`: **1/1 Running** (0 restarts)
- `between-celery-69b4798fbf-zchmk`: **1/1 Running** (1 restart during reboot)
- `between-frontend-697d678d77-gwlzv`: **1/1 Running** (3 restarts during initial memory tuning)
- `between-redis-659c8db59c-pjm6v`: **1/1 Running** (1 restart during reboot)

### System Workloads (`kube-system`)
- `traefik-846cf67878-h6smc`: **1/1 Running** (0 restarts)
- `local-path-provisioner-77b9867795-86rnt`: **1/1 Running**
- `coredns-54996dc9b4-s9gm8`: **1/1 Running**
- `svclb-traefik-1e86ebef-56cd5`: **2/2 Running**

### Persistent Volume Claims
- `between-uploads-pvc`: 5 GiB `local-path`, Status: **Bound**
- `traefik` (ACME storage): 128 MiB `local-path`, Status: **Bound**

---

## ArgoCD

**STATUS: PASS**

- **Namespace**: `argocd`
- **Application Name**: `between-staging`
- **Health Status**: **`Healthy`**
- **Sync Status**: **`Synced`**
- **Automated Sync**: Enabled (`automated: { prune: true, selfHeal: false }`)
- **Tracked Revision**: `2566eea523c0a1e1fbb991f22002b017c3f09c13`
- **Reconciliation Time**: `05:53:07 UTC` (reconciled automatically upon git push)
- **Active Core Pods**:
  - `argocd-server`: 1/1 Running
  - `argocd-repo-server`: 1/1 Running
  - `argocd-application-controller-0`: 1/1 Running
  - `argocd-redis`: 1/1 Running
- **Intentional Resource Sizing**: Non-essential services (`dex-server`, `applicationset-controller`, `notifications-controller`) intentionally set to `0/0` replicas to conserve RAM on the 2GB host.

---

## AWS EC2

**STATUS: PASS**

- **Instance ID**: `i-0b49f1e35eeca2dc2`
- **Instance Type**: `t3.small` (2 vCPUs, 2.0 GiB RAM)
- **Region & AZ**: `ap-south-1b`
- **Public IPv4**: `13.201.134.20`
- **Current State**: `running`
- **Load Average**: `1.47, 1.08, 0.81`
- **Memory Utilization**: 1.7 GiB used / 1.9 GiB total; ~200 MiB available buffer
- **Swap Status**: 4.0 GiB swapfile enabled; 819 MiB used / 3.2 GiB free buffer
- **Root Disk Utilization**: 29 GiB gp3 EBS volume; 12 GiB used / 17 GiB available (43% utilization)

---

## AWS RDS

**STATUS: PASS**

- **DB Identifier**: `between-prod-db`
- **Instance Class**: `db.t4g.micro` (AWS Graviton2 64-bit ARM)
- **Engine**: PostgreSQL 15.13
- **Current Status**: `available`
- **Endpoint**: `between-prod-db.cl4oaaweopzg.ap-south-1.rds.amazonaws.com:5432`
- **Public Accessibility**: `False` (isolated in private subnet group across `ap-south-1a`, `ap-south-1b`, `ap-south-1c`)
- **Security Group (`sg-02e6070330f3a5524`)**: TCP 5432 ingress restricted exclusively to the k3s EC2 security group `sg-0590cd801dfc08813`
- **Django Migrations**: Executed `python manage.py showmigrations` inside backend container:
  - 41 `api` migrations: **`[X]` All applied**
  - 3 `admin`, 12 `auth`, 2 `contenttypes`, 1 `sessions` migrations: **`[X]` All applied**
  - **Zero pending migrations, zero schema drift**
- **Kubernetes Database Footprint**: Zero database pods running in k3s.

---

## Redis / Celery

**STATUS: PASS**

- **Redis**: Internal ClusterIP service `between-redis:6379`, database 1 allocated for Celery broker/results.
- **Celery Worker**: Deployed with `--pool=solo --concurrency=2` to eliminate memory spikes.
- **Connection**: Log verified: `Connected to redis://between-redis:6379/1`.
- **Worker State**: Ready and active on queue `celery`.
- **Registered Tasks (7)**:
  - `enrich_candidates_llm`
  - `match_all_candidates`
  - `process_resume_batch`
  - `release_round_results`
  - `sync_gdrive_resumes`
  - `sync_gmail_resumes`
  - `sync_google_form_resumes`

---

## HTTPS / TLS

**STATUS: PASS**

- **Edge Proxy**: Traefik v3 (`rancher/mirrored-library-traefik:3.7.8`).
- **Domain Verification**: AWS Route 53 A-record points `between.dakshaws.sryze.cc` -> `13.201.134.20`.
- **Certificate Authority**: Let's Encrypt (`YR1`).
- **Common Name (CN)**: `between.dakshaws.sryze.cc`.
- **Subject Alternative Names**: `DNS:between.dakshaws.sryze.cc`.
- **Validity Window**: September 25, 2026 to December 24, 2026.
- **ACME Solver**: Traefik HTTP-01 challenge solver validated and issued certificate in real-time.
- **Storage Persistence**: ACME state saved to `/data/acme.json` on persistent volume `pvc/traefik` (128 MiB `local-path`).
- **HTTP-to-HTTPS Redirection**: Automatic `HTTP 301 Moved Permanently` on port 80.

---

## Security

**STATUS: PASS**

- **EC2 Security Group (`sg-0590cd801dfc08813`)**:
  - Ports 80 & 443: Open to `0.0.0.0/0` (public web ingress)
  - Port 22 (SSH): Restricted to operator CIDR `152.58.0.0/16`
  - Port 6443 (k3s API): Restricted to operator CIDR `152.58.0.0/16`
- **RDS Security Group (`sg-02e6070330f3a5524`)**:
  - Port 5432: Strictly restricted to EC2 SG `sg-0590cd801dfc08813`
  - Public access: Completely disabled (`0.0.0.0/0` blocked)
- **Container Hardening**:
  - Workloads execute with `runAsNonRoot: true`, UID 1000
  - Privilege escalation disabled (`allowPrivilegeEscalation: false`)
  - Linux capabilities dropped (`drop: ["ALL"]`)
- **Secret Hygiene**:
  - Zero `.pem`, `.key`, `.env`, or kubeconfig files tracked in Git.
  - Secret templates in Git contain only dummy placeholders.

---

## Backup / Disaster Recovery

**STATUS: PASS WITH WARNINGS**

### Verified in Production:
- **Automated RDS Snapshots**: Daily automated snapshot policy active (`BackupRetentionPeriod: 1` day, backup window `17:58-18:28 UTC`).
- **Active Snapshot**: `rds:between-prod-db-2026-09-25-01-48` verified in `available` state (20 GiB gp3).
- **Point-in-Time Recovery**: Active with restorable transaction history up to `2026-09-25T05:48:38 UTC`.
- **Manifest Portability**: All cluster configuration is fully reproducible via Kustomize in Git.

### Documented but Not Executed:
- **Destructive Database Restore**: Per operating safety rules, restoring a database snapshot was validated via read-only API inspection; no destructive restore was executed against the live database.
- **Warning / Trade-off**: Media uploads (`/app/uploads` and `/app/photos`) currently reside on k3s `local-path-provisioner` EBS storage. If the EC2 host is terminated without EBS preservation, uploaded resume PDFs must be regenerated or restored. Migration to AWS S3 is documented in [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) for future multi-node expansion.

---

## Cost Controls

**STATUS: PASS**

- **Frugal Architecture**: Intentionally eliminates expensive AWS resources:
  - No AWS Application Load Balancer ($18–$25/mo saved via Traefik ServiceLB HostPort).
  - No AWS NAT Gateway ($32+/mo saved via single VPC architecture).
  - No idle Elastic IP charges ($3.65/mo saved).
- **One-Click Automation**:
  - [Between-AWS-Toggle.bat](Between-AWS-Toggle.bat) and [between-aws-toggle.ps1](between-aws-toggle.ps1) verified present.
  - Safely pauses EC2 and RDS instances when the project is not in active use, reducing idle cloud billing by up to 70%.

---

## Documentation

**STATUS: PASS**

All system documentation is updated, consistent, and accurately reflects the live production architecture:
1. [README.md](README.md) — Production URL, badges, technology stack, and architecture references.
2. [ARCHITECTURE.md](ARCHITECTURE.md) — Technical specifications, network topology, routing rules, and resource allocations.
3. [DEPLOYMENT.md](DEPLOYMENT.md) — GitOps release lifecycle, secret separation model, and operational runbook.
4. [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) — Backup schedules, snapshot recovery procedures, and storage limitations.
5. [SECURITY.md](SECURITY.md) — Infrastructure security matrix, container hardening, and least-privilege policies.
6. [PRODUCTION-EVIDENCE.md](PRODUCTION-EVIDENCE.md) — Factual engineering achievements and verified resume bullet options.

---

## Resume Evidence

**STATUS: PASS**

Full evidence portfolio compiled in [PRODUCTION-EVIDENCE.md](PRODUCTION-EVIDENCE.md), featuring 3 interview-ready resume bullet options covering DevOps, Kubernetes Platform Engineering, and Site Reliability Engineering.

---

## Verified Items

1. [x] Public HTTPS endpoint `https://between.dakshaws.sryze.cc/` returns HTTP 200 OK.
2. [x] HTTP port 80 permanently redirects to HTTPS port 443 with HTTP 301.
3. [x] Let's Encrypt TLS certificate issued for `between.dakshaws.sryze.cc` (valid through Dec 24, 2026).
4. [x] Traefik ACME challenge persistence backed by PVC `local-path` volume.
5. [x] GitHub Actions CI workflow `Docker CI & GHCR Publishing` succeeded cleanly.
6. [x] GHCR containers published and pulled with immutable commit SHA tags.
7. [x] ArgoCD application `between-staging` is `Synced` and `Healthy`.
8. [x] Kubernetes workloads (`backend`, `celery`, `frontend`, `redis`, `traefik`, `argocd`) all 1/1 Running.
9. [x] Single-node RWO PVC deadlock resolved via `strategy.type: Recreate`.
10. [x] AWS RDS PostgreSQL 15.13 is private, reachable, and in zero-drift migration state.
11. [x] Celery worker connected to Redis broker with 7 registered background tasks.
12. [x] Database-backed endpoint `/api/v1/dynamic-data` verified returning data over HTTPS.
13. [x] Security groups verified: EC2 administrative ports (22, 6443) restricted to operator CIDR; RDS restricted to EC2 SG.
14. [x] Zero plaintext secrets or private keys tracked in Git.
15. [x] Automated daily RDS snapshot verified available in AWS.
16. [x] One-click AWS cost management toggle script verified present and credential-free.

---

## Not Tested / Documented Only

1. **Destructive RDS Database Restore**: Not executed against the active production database to prevent service interruption. Procedure documented and verified via AWS CLI snapshot availability.
2. **Cluster Cold-Rebuild**: Full EC2 instance teardown and reprovisioning not executed on live system. Documented step-by-step in `DISASTER-RECOVERY.md`.
3. **High-Concurrency Load Testing**: Not executed to avoid exceeding the 2GB memory boundary on the `t3.small` instance.

---

## Remaining Risks & Mitigations

| Risk | Severity | Mitigation in Place |
| :--- | :--- | :--- |
| **Node RAM Exhaustion (2GB host)** | Medium | Workloads constrained to 1 replica; Celery configured in solo pool; 4GB swapfile absorbs temporary allocation bursts; non-essential ArgoCD pods scaled down. |
| **Dynamic Public IPv4 Change on EC2 Stop** | Low | Documented in `between-aws-toggle.ps1` to re-check public IP upon restart and update Route 53 A-record if dynamic IP changes (or allocate an Elastic IP). |
| **Local-Path Storage for Uploads** | Low | Uploaded resume PDFs stored locally on EBS; architectural path to migrate media storage to AWS S3 documented in `DISASTER-RECOVERY.md`. |

---

## Final Verdict

```text
PHASE 10 — PASS
```

All production systems, continuous delivery workflows, cryptographic certificates, network controls, and documentation are verified and operational.
