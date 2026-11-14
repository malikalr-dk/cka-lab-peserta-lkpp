#!/usr/bin/env bash
# LAB-15 reset: delete namespace cka-lab15 and recreate starter state (Deployment web, Service web,
# and broken-route with port 8080). Leave Gateway API CRDs and Traefik installed.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab15"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
STARTER_YAML="${SCRIPT_DIR}/../starter/manifests.yaml"
# `bash -s < reset.sh` (the documented remote runner) makes BASH_SOURCE /dev/stdin, so
# SCRIPT_DIR resolves to /dev and this script used to fail with "manifests tidak ditemukan".
if [[ ! -f "$STARTER_YAML" ]]; then
  STARTER_YAML="/opt/lab/labs/LAB-15/starter/manifests.yaml"
fi

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
# A terminating namespace still answers 'create' with AlreadyExists; wait for it to be gone.
for _ in $(seq 1 60); do
  kubectl get namespace "$NS" >/dev/null 2>&1 || break
  sleep 2
done
kubectl create namespace "$NS" >/dev/null

if [[ -f "$STARTER_YAML" ]]; then
  if ! kubectl apply -f "$STARTER_YAML" >/dev/null; then
    printf 'FAIL: kubectl apply %s gagal — namespace %s tidak kembali ke state awal\n' "$STARTER_YAML" "$NS" >&2
    exit 1
  fi
else
  printf 'FAIL: %s tidak ditemukan — state awal LAB-15 tidak bisa dipulihkan\n' "$STARTER_YAML" >&2
  exit 1
fi

printf 'INFO: waiting up to 45s for Deployment %s/web rollout...\n' "$NS"
kubectl -n "$NS" rollout status deployment/web --timeout=45s >/dev/null 2>&1 || true
printf 'Reset complete: namespace %s restored to starter state (Gateway API CRDs and Traefik kept installed)\n' "$NS"
exit 0
