#!/usr/bin/env bash
# LAB-08 starter: create clean namespace cka-lab08 and ensure worker nodes do not carry leftover label/taint.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab08"

w1_node="$(kubectl get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E '^cka-p[0-9]+-w1$' | head -1)"
w2_node="$(kubectl get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E '^cka-p[0-9]+-w2$' | head -1)"

if [[ -n "$w1_node" ]]; then
  kubectl label node "$w1_node" disk- >/dev/null 2>&1 || true
fi
if [[ -n "$w2_node" ]]; then
  kubectl taint node "$w2_node" dedicated=lab:NoSchedule- >/dev/null 2>&1 || true
  kubectl taint node "$w2_node" dedicated:NoSchedule- >/dev/null 2>&1 || true
fi

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null 2>&1 || true

printf 'READY: namespace %s created for LAB-08\n' "$NS"
