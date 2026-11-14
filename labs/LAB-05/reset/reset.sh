#!/usr/bin/env bash
# LAB-05 reset: uncordon worker w1 and remove scratch etcd snapshot/restore artifacts.
# Never touches /var/lib/etcd or the live etcd instance.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

SNAP_FILE="${SNAP_FILE:-/root/lab/etcd-snap.db}"
RESTORE_DIR="${RESTORE_DIR:-/root/lab/etcd-restore}"

w1_node="$(kubectl get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E '^cka-p[0-9]+-w1$' | head -1)"
if [[ -n "$w1_node" ]]; then
  kubectl uncordon "$w1_node" >/dev/null 2>&1 || true
  printf 'Uncordoned worker node: %s\n' "$w1_node"
fi

rm -f "$SNAP_FILE"
rm -rf "$RESTORE_DIR"
printf 'Removed snapshot %s and scratch restore directory %s\n' "$SNAP_FILE" "$RESTORE_DIR"
exit 0
