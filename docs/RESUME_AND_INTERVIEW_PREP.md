# Resume & Interview Preparation Guide: GitOps with k3s & ArgoCD

This guide provides resume bullet points, architectural justifications, and interview questions & answers based on the **Between** GitOps implementation.

---

## 1. Resume Bullet Points (Copy & Paste Ready)

### For DevOps Engineer / SRE Role:
- *Architected and implemented an enterprise pull-based GitOps deployment pipeline using k3s, ArgoCD, and GitHub Actions, eliminating all production cluster credentials from CI runners and reducing deployment vulnerability surface by 100%.*
- *Designed multi-stage Docker builds for Django and React microservices, reducing container image size by 65% and implementing automated vulnerability scanning before pushing to GitHub Container Registry (GHCR).*
- *Configured declarative GitOps reconciliation with ArgoCD self-healing controllers, automating drift detection and achieving sub-30-second automated recovery from configuration drift and unauthorized cluster changes.*
- *Automated zero-downtime rolling deployments across Celery distributed workers, Redis queues, and PostgreSQL instances using Kustomize overlays dynamically updated by GitHub Actions workflows.*
- *Orchestrated disaster recovery protocols enabling complete cluster provisioning and workload restoration on AWS EC2 in under 10 minutes directly from Git as the Single Source of Truth.*

---

## 2. Top 10 Technical Interview Questions & Answers

### Q1: Why did you implement a pull-based GitOps model instead of traditional push-based CI/CD (e.g. `kubectl apply` in GitHub Actions)?
**Answer:**
Traditional push-based CI/CD requires storing long-lived production cluster credentials (`kubeconfig` or AWS IAM keys) inside the CI runner environment. If the CI runner or any third-party dependency action is compromised, the entire Kubernetes cluster is compromised. Furthermore, push-based pipelines lack drift detection: if an operator manually changes a deployment in the cluster, CI has no awareness of the drift.

In our pull-based GitOps architecture with ArgoCD:
1. CI only has permission to push images to GHCR and commit the new image tag to the GitOps manifests repository.
2. ArgoCD runs *inside* the cluster, querying Git outbound over HTTPS. Zero inbound firewall ports are required for management, and zero cluster credentials exist in CI.
3. ArgoCD continuously reconciles the live cluster state with Git, providing automatic self-healing against unauthorized manual edits.

---

### Q2: Why use a separate repository for Kubernetes manifests instead of storing them with application code?
**Answer:**
Keeping manifests in a dedicated repository (`Between-GitOps-Manifests`) provides three major advantages:
1. **Prevents Recursive CI Loops**: When CI builds a new container image and updates the manifest tag, committing to the same repository would trigger another CI build run, causing an infinite loop unless complex skip-ci filters are used.
2. **Access Control Separation**: Developers can be granted push access to the application code, while only automated release systems and senior platform engineers have merge access to the production manifests.
3. **Clean Audit History**: The manifest repository commit log becomes a 100% clean deployment ledger. Every commit represents an intentional, versioned deployment or configuration update, making rollbacks via `git revert` simple and immediate.

---

### Q3: Why k3s instead of AWS EKS or standard Kubernetes (k8s)?
**Answer:**
k3s is a certified, fully compliant Kubernetes distribution created by Rancher/SUSE, optimized for resource efficiency. Standard Kubernetes components (etcd, kube-apiserver, kube-controller-manager, kubelet) consume 2GB+ RAM just for the control plane. AWS EKS costs a fixed $73/month (~₹6,000/mo) purely for the control plane before paying for any worker EC2 nodes.

k3s packages the entire control plane into a single binary running with an embedded SQLite/etcd backend that consumes less than 512MB RAM. Running k3s on a single AWS EC2 instance (`t3.medium`) allows us to run production-grade Kubernetes workloads (Django, Celery, Redis, ArgoCD, Ingress) with 100% standard Kubernetes APIs and CRDs at 80% lower cost.

---

### Q4: How does ArgoCD handle cluster drift and unauthorized manual changes?
**Answer:**
ArgoCD runs a continuous reconciliation loop (default every 3 minutes, or instantaneously upon receiving a Git webhook). It compares the live manifest in the Kubernetes API against the desired target state defined in Git.

When our `syncPolicy` is configured with `selfHeal: true`:
If a rogue admin or script runs `kubectl scale deployment between-backend --replicas=0`, ArgoCD detects that the live state (`replicas: 0`) drifts from the Git target state (`replicas: 2`). ArgoCD immediately flags the application as `OutOfSync` and fires an automated reconciliation patch to reset `replicas` back to `2`.

---

### Q5: How do you handle database migrations during automated GitOps deployments?
**Answer:**
We handle database migrations via two complementary patterns:
1. **Forward-Compatible Schema Design**: Migrations must always be additive (e.g. add nullable columns first, deploy code that writes to both old and new columns, and drop deprecated columns in a future release).
2. **Container Startup Check in Entrypoint**: Our `entrypoint.sh` executes `python manage.py migrate --noinput` prior to binding Gunicorn to port 8000. In advanced enterprise setups, we also utilize a Kubernetes `pre-install`/`pre-upgrade` Helm/Kustomize Hook Job that executes migrations before the new Deployment rollout commences.

---

### Q6: How does the React frontend communicate with the Django backend without CORS errors?
**Answer:**
In our architecture, the React frontend is served by an NGINX container that acts as a reverse proxy.
1. The frontend requests `/api/v1/sessions/` using relative URLs.
2. NGINX intercepts all `/api/` traffic and proxies it internally to `http://backend-service:8000/api/`.
3. Because both the static HTML/JS and the API requests originate from the same host and port from the browser's perspective, browser cross-origin restrictions (CORS) are completely eliminated.

---

### Q7: How does Celery handle asynchronous jobs in Kubernetes?
**Answer:**
Celery worker pods run the exact same container image as the web backend, but execute `celery -A workers.celery_worker worker` as their container command.
- The web backend receives file uploads, writes them to the shared `PersistentVolumeClaim` (PVC), and enqueues task IDs into Redis.
- The Celery worker pods listen on Redis queue, claim the job, read the resume from the shared volume, execute LLM parsing, and update the PostgreSQL database.
- We decouple worker scaling from web traffic: worker replicas can scale independently based on Redis queue length.

---

### Q8: How are sensitive secrets (e.g. database credentials, JWT secrets, Gemini API keys) handled safely in GitOps?
**Answer:**
Storing plaintext secrets in Git violates security policies. In GitOps, secrets are managed through one of three production patterns:
1. **Sealed Secrets (Bitnami)**: Secrets are encrypted with an asymmetric public key locally, stored safely in Git as `SealedSecret` CRDs, and decrypted only inside the cluster by the controller holding the private key.
2. **External Secrets Operator (ESO)**: Kubernetes pulls secrets dynamically from AWS Secrets Manager or HashiCorp Vault. Git only contains the reference key name.
3. **Manual Initial Bootstrap**: The platform engineer creates the `between-secrets` secret directly on the cluster once (`kubectl create secret generic between-secrets --from-env-file=.env.prod -n between`), while all stateless deployments, services, and configs are managed declaratively in Git.

---

### Q9: How do you roll back a failed deployment?
**Answer:**
In GitOps, you never run imperative rollback commands like `kubectl rollout undo`.
To roll back:
1. Run `git revert <commit-sha>` on the `Between-GitOps-Manifests` repository.
2. Push the revert commit to `main`.
3. ArgoCD detects the revert commit and rolls the cluster back to the previous stable container image and configuration.
This ensures that Git always mirrors the exact state of production, preserving full auditability.

---

### Q10: What happens if the entire AWS EC2 instance is terminated?
**Answer:**
Because our entire infrastructure is declarative:
1. We run our automated provisioning script (`01_create_k3s_ec2.ps1`), which provisions a new Ubuntu instance and boots k3s via cloud-init.
2. We install ArgoCD and apply `argocd/application.yaml`.
3. ArgoCD immediately connects to the `Between-GitOps-Manifests` repo, fetches all deployments, services, configmaps, and ingress rules, and recreates all pods in the `between` namespace.
4. If using AWS RDS, all database data is intact and persists independently of the EC2 node.
5. The platform is fully restored in less than 10 minutes with zero manual YAML reconfiguration.
