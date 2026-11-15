#!/usr/bin/env bash
# LAB-18 reset: delete namespace cka-lab16 and CRD configforges.lab.example.com,
# and leave Traefik (and its CRDs) installed.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab16"
CRD_NAME="configforges.lab.example.com"

kubectl -n "$NS" delete configforges.lab.example.com --all --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "$NS" delete ingressroutes.traefik.io --all --ignore-not-found >/dev/null 2>&1 || true
kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete crd "$CRD_NAME" --ignore-not-found >/dev/null 2>&1 || true

printf 'Reset complete: deleted namespace %s and deleted CustomResourceDefinition %s (Traefik kept installed)\n' "$NS" "$CRD_NAME"
exit 0
