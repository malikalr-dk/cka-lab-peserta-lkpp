#!/usr/bin/env bash
# LAB-05 starter: ensure worker w1 is uncordoned and /root/lab is clean of previous etcd snapshot artifacts.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

mkdir -p /root/lab
rm -f /root/lab/etcd-snap.db
rm -rf /root/lab/etcd-restore

w1_node="$(kubectl get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E '^cka-p[0-9]+-w1$' | head -1)"
if [[ -n "$w1_node" ]]; then
  kubectl uncordon "$w1_node" >/dev/null 2>&1 || true
fi

printf 'READY: /root/lab initialized and worker node uncordoned for LAB-05\n'
