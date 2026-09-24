#!/bin/bash
set -e

echo "=== Installing ArgoCD on k3s ==="
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

echo "=== ArgoCD Initial Admin Password ==="
ADMIN_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Username: admin"
echo "Password: $ADMIN_PASS"
echo "Save this password securely!"

echo "=== Applying Between Application to ArgoCD ==="
kubectl apply -f application.yaml

echo "ArgoCD setup complete!"
