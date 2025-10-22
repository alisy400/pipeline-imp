#!/usr/bin/env bash
set -euo pipefail

# Expects:
# - kubectl configured (KUBECONFIG or aws eks update-kubeconfig used)
# - IMAGE env var set (full ECR image uri)
if [ -z "${IMAGE:-}" ]; then
  echo "IMAGE env var required"
  exit 2
fi

# if deployment exists update image, else apply manifests
if kubectl get deployment device-monitor >/dev/null 2>&1; then
  echo "Updating deployment image to ${IMAGE}"
  kubectl set image deployment/device-monitor device-monitor="${IMAGE}" --record
else
  echo "Applying manifests (substituting image into deployment)"
  tmpfile=$(mktemp)
  sed "s|REPLACE_WITH_IMAGE|${IMAGE}|g" k8s/deployment.yaml > "${tmpfile}"
  kubectl apply -f "${tmpfile}"
  kubectl apply -f k8s/service.yaml
  rm -f "${tmpfile}"
fi

echo "Waiting for rollout..."
kubectl rollout status deployment/device-monitor --timeout=180s
kubectl get pods -l app=device-monitor -o wide
