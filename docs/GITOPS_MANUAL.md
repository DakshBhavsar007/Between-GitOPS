# Between GitOps Operations & Runbook Manual

This manual provides instructions for deploying, operating, maintaining, and disaster-recovering the **Between** platform via GitOps.

---

## 1. Initial Setup Checklist

### Step 1: Create the GitOps Manifests Repository on GitHub
1. Create a new repository on your GitHub account: `Between-GitOps-Manifests`.
2. Push the local `gitops-manifests/` folder content to this repository:
   ```bash
   cd gitops-manifests
   git init
   git branch -M main
   git remote add origin https://github.com/<YOUR_GITHUB_USER>/Between-GitOps-Manifests.git
   git add .
   git commit -m "feat(gitops): initial k8s manifests"
   git push -u origin main
   ```

### Step 2: Set up GitHub Secrets
In your main application repository (`Between-GitOps`):
Go to **Settings > Secrets and variables > Actions > New repository secret**:
- `GITOPS_TOKEN`: A GitHub Personal Access Token (PAT) with `repo` scope to allow CI to commit to `Between-GitOps-Manifests`.

### Step 3: Launch AWS EC2 Instance with k3s
Run the PowerShell provisioning script:
```powershell
.\scripts\aws\01_create_k3s_ec2.ps1
```
Or the Bash script on Linux/macOS:
```bash
bash scripts/aws/01_create_k3s_ec2.sh
```

### Step 4: Install ArgoCD & Apply Application
SSH into the EC2 instance:
```bash
ssh -i <your-key>.pem ubuntu@<EC2-PUBLIC-IP>
```
Install ArgoCD:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```
Apply the Application definition:
```bash
kubectl apply -f https://raw.githubusercontent.com/<YOUR_GITHUB_USER>/Between-GitOps/main/argocd/application.yaml
```

---

## 2. Daily Developer Flow

1. Developer makes code changes on a local branch.
2. Commits and pushes to `main`:
   ```bash
   git add .
   git commit -m "feat: enhance resume scoring algorithm"
   git push origin main
   ```
3. **Automated Pipeline execution**:
   - GitHub Actions runs quality checks.
   - Builds backend & frontend Docker images and pushes to GHCR.
   - Updates `overlays/prod/kustomization.yaml` in `Between-GitOps-Manifests` with the new commit SHA.
   - ArgoCD detects the change within 3 minutes (or immediately via webhook) and performs a rolling deployment in k3s.
   - Zero downtime!

---

## 3. Rollback Procedure

To roll back a bad deployment in GitOps, **never use `kubectl rollout undo`**. In GitOps, Git is the single source of truth.

To roll back:
```bash
cd Between-GitOps-Manifests
git revert HEAD
git push origin main
```
ArgoCD instantly observes the Git revert and rolls the cluster back to the previous known good state!

---

## 4. Disaster Recovery (Rebuild Cluster in 10 Minutes)

If the entire EC2 instance crashes or is accidentally terminated:
1. Re-run `01_create_k3s_ec2.ps1` to spin up a new EC2 instance with k3s.
2. Install ArgoCD on the new instance.
3. Apply `argocd/application.yaml`.
4. ArgoCD pulls all manifests from `Between-GitOps-Manifests` and recreates all deployments, services, configs, and ingress automatically!
5. Point your domain DNS to the new Elastic IP. Full recovery completed in under 10 minutes.
