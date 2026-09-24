#!/bin/bash
set -e

echo "=========================================================="
echo "      BETWEEN GITOPS SELF-HEALING & DRIFT RECOVERY TEST   "
echo "=========================================================="
echo ""

echo ">>> Step 1: Checking current healthy deployment state..."
kubectl get deployment between-backend -n between
kubectl get pods -n between -l app=between-backend

echo ""
echo ">>> Step 2: Simulating manual drift / unauthorized sabotage..."
echo "Running: kubectl scale deployment between-backend --replicas=0 -n between"
kubectl scale deployment between-backend --replicas=0 -n between

echo "State right after manual sabotage (0 replicas):"
kubectl get deployment between-backend -n between

echo ""
echo ">>> Step 3: Waiting for ArgoCD Self-Healing controller..."
echo "ArgoCD detects drift between Git desired-state (2 replicas) and live cluster state (0 replicas)..."
sleep 10

for i in {1..12}; do
    CURRENT_REPLICAS=$(kubectl get deployment between-backend -n between -o jsonpath='{.spec.replicas}')
    echo "[$i] Current Replicas in Cluster: $CURRENT_REPLICAS"
    if [ "$CURRENT_REPLICAS" -eq 2 ]; then
        echo ""
        echo "=========================================================="
        echo " SUCCESS! GITOPS SELF-HEALING ENFORCED!"
        echo " ArgoCD automatically restored deployment to 2 replicas!"
        echo "=========================================================="
        break
    fi
    sleep 5
done

echo ""
echo ">>> Step 4: Final verification of resurrected pods:"
kubectl get pods -n between -l app=between-backend
