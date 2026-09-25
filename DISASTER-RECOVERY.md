# Disaster Recovery & Business Continuity Plan

This document outlines the Disaster Recovery (DR) and Business Continuity protocols for the **Between** (Vishleshan) AI Resume Intelligence Platform.

---

## 1. Objectives & Metrics

- **Recovery Point Objective (RPO)**: <= 24 hours (governed by daily automated AWS RDS snapshots).
- **Recovery Time Objective (RTO)**: <= 30 minutes (complete cluster recreation from GitOps repository).

---

## 2. Component Failure Matrix & Recovery Protocols

| Component | Failure Mode | Impact | Recovery Protocol |
| :--- | :--- | :--- | :--- |
| **AWS EC2 Instance** | Hardware failure, AZ outage, accidental termination | Total downtime | Provision new EC2 instance via launch template / script, install k3s, and run `kubectl apply -k gitops-manifests/overlays/staging`. |
| **AWS RDS PostgreSQL** | Instance crash, corruption, accidental DROP | Data loss risk | Restore from automated RDS snapshot or point-in-time recovery (PITR) window (17:58-18:28 UTC). |
| **k3s Control Plane** | SQLite database corruption, OOM lockup | API unresponsive | Flush swap / reboot instance (`aws ec2 reboot-instances`), or reinstall k3s and restore manifests from Git. |
| **Local-Path PVC** | EBS volume corruption, host termination | Uploaded PDFs / avatars lost | Recreate PVC via manifests; see Section 3 for durable storage migration. |
| **Application Pods** | Process crash, uncaught exception | Transient 502/503 | Kubernetes liveness and readiness probes automatically restart unhealthy containers within 45s. |

---

## 3. Storage Architecture & Limitations

### Current Implementation: `local-path` StorageClass
```text
local-path PVC != durable multi-node cloud storage
```
The staging cluster uses k3s default `local-path-provisioner` on the root EBS volume (`/var/lib/rancher/k3s/storage`).
- **Limitation**: If the EC2 instance is terminated without a persistent EBS snapshot, data in `/app/uploads` and `/app/photos` will be lost.
- **Production Roadmap**: For business-critical production deployments, media storage should be migrated to **AWS S3** with `django-storages`, offloading media persistence completely from the compute node.

---

## 4. Database Backup & Restore

### Automated Snapshots
AWS RDS PostgreSQL (`between-prod-db`) is configured with automated daily backups:
- **Backup Window**: 17:58 - 18:28 UTC
- **Retention Period**: 1 day (expandable to 7-35 days for production)
- **Storage**: 20 GiB gp3 (auto-scaling enabled up to 1,000 GiB)

### Restoring from Snapshot
```bash
# 1. Identify latest automated snapshot
aws rds describe-db-snapshots \
  --db-instance-identifier between-prod-db \
  --region ap-south-1 \
  --query "DBSnapshots[-1].DBSnapshotIdentifier"

# 2. Restore to a new instance
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier between-prod-db-restored \
  --db-snapshot-identifier <snapshot-id> \
  --db-instance-class db.t4g.micro \
  --region ap-south-1

# 3. Update Kubernetes secret with restored endpoint
kubectl patch secret between-secrets -n between --type=merge \
  -p '{"stringData":{"DATABASE_URL":"postgresql://postgres:<password>@<new-rds-endpoint>:5432/vishleshan"}}'
```

---

## 5. Cost Management Stop/Start & IP Recovery

The repository includes a one-click cost management utility: `Between-AWS-Toggle.bat` (and `between-aws-toggle.ps1`).

### State Transition
```text
Running  ->  Gracefully Stop EC2  ->  Stop RDS  (Minimizes compute charges)
Stopped  ->  Start RDS (Available)  ->  Start EC2  (Ensures DB ready before k3s boots)
```

### Public IP Handling After Restart
- **Without Elastic IP**: Stopping and starting an EC2 instance dynamically changes its public IPv4 address.
  - **Required Action**: After restart, query the new public IP:
    ```bash
    aws ec2 describe-instances --filters "Name=tag:Name,Values=between-k3s-server" \
      --region ap-south-1 --query "Reservations[0].Instances[0].PublicIpAddress" --output text
    ```
  - Update your DNS A record (`between.indevs.in`) with the new public IP.
- **With Elastic IP**: Allocating an Elastic IP (`eipalloc-...`) maintains a static IP across stop/start cycles ($0.005/hr when instance is stopped).

---

## 6. Cold-Cluster Rebuilding Procedure

If the entire cluster must be rebuilt from scratch:

```bash
# 1. Install k3s on Ubuntu 24.04
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# 2. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Apply GitOps Manifests
kubectl apply -k gitops-manifests/overlays/staging

# 4. Create Production Secrets
kubectl create secret generic between-secrets -n between \
  --from-literal=DATABASE_URL="postgresql://postgres:<password>@<rds-endpoint>:5432/vishleshan" \
  --from-literal=REDIS_URL="redis://between-redis:6379/1" \
  --from-literal=JWT_SECRET="<jwt-secret>" \
  --from-literal=GEMINI_API_KEY="<api-key>" \
  --from-literal=TWOFACTOR_API_KEY="<api-key>" \
  --from-literal=ADMIN_EMAIL="admin@between.com" \
  --from-literal=ADMIN_PASSWORD="<password>"

# 5. Apply ArgoCD Application
kubectl apply -f argocd/application.yaml
```
All application pods will deploy, apply migrations, collect static assets, and become fully operational within 3 minutes.

---

## 5. Routine Cost Management & Cold Start Automation

To shut down compute during prolonged periods of inactivity or bring the system back online without manual intervention:

- **Launch Command**: Double-click `Between-AWS-Toggle.bat`.
- **Automatic Sequence**:
  - **Shutdown (RUNNING → STOP)**: Prompts for `(Y/N)` confirmation, gracefully stops the EC2 instance first, then stops the RDS instance.
  - **Cold Start (STOPPED → START)**:
    1. Starts RDS PostgreSQL first, actively polling until `DBInstanceStatus == available`.
    2. Starts EC2 instance and waits until `running`.
    3. Detects whether an Elastic IP is present. If dynamic IPv4 is allocated, compares with Route 53 A-record for `between.dakshaws.sryze.cc` and performs an automatic Route 53 UPSERT (TTL: 300).
    4. Waits for k3s, Traefik, Nginx, and Django to boot, verifying HTTP 200 on `https://between.dakshaws.sryze.cc/healthz`, `/`, and `/api/v1/health`.
- **Storage & AWS Caveats**:
  - Stopping compute pauses EC2 and RDS hourly charges.
  - Persistent EBS (30GB gp3) and RDS allocated storage (20GB gp3) continue to accrue storage fees (~$5.00/month).
  - Route 53 hosted zone charges remain active (~$0.50/month).
  - **RDS 7-Day Limit**: AWS automatically restarts stopped RDS databases after 7 consecutive days if not started manually.

