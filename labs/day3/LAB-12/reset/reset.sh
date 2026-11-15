#!/usr/bin/env bash
# LAB-12 reset: delete namespace gisp-app (and any leftover PVs bound to gisp-app),
# recreate gisp-app empty, and leave Traefik untouched.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="gisp-app"

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true

# Clean up any leftover PVs created for gisp-app in case a participant set Retain
pvs="$(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.claimRef.namespace}{"\n"}{end}' 2>/dev/null | awk '$1 ~ /^pvc-/ && $2 == "gisp-app" {print $1}' || true)"
for pv in $pvs; do
  kubectl delete pv "$pv" --ignore-not-found >/dev/null 2>&1 || true
done

kubectl create namespace "$NS" >/dev/null 2>&1 || true
printf 'Reset complete: namespace %s recreated empty (Traefik left untouched)\n' "$NS"
exit 0
