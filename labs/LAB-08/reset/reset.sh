#!/usr/bin/env bash
# LAB-08 reset: remove the dedicated=lab:NoSchedule taint from w2, remove disk=fast label from w1,
# and recreate namespace cka-lab08 cleanly.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab08"

w1_node="$(kubectl get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E '^cka-p[0-9]+-w1$' | head -1)"
w2_node="$(kubectl get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E '^cka-p[0-9]+-w2$' | head -1)"

if [[ -n "$w1_node" ]]; then
  kubectl label node "$w1_node" disk- >/dev/null 2>&1 || true
  printf 'Removed label disk from %s\n' "$w1_node"
fi

if [[ -n "$w2_node" ]]; then
  kubectl taint node "$w2_node" dedicated=lab:NoSchedule- >/dev/null 2>&1 || true
  kubectl taint node "$w2_node" dedicated:NoSchedule- >/dev/null 2>&1 || true
  printf 'Removed taint dedicated=lab:NoSchedule from %s\n' "$w2_node"
fi

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null 2>&1 || true
printf 'Reset complete: namespace %s recreated cleanly\n' "$NS"
exit 0
