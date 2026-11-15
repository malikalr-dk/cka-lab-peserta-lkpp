#!/usr/bin/env bash
# LAB-04 reset: kubeadm reset -f on the workers only (cka-pN-w1 and cka-pN-w2).
# Does NOT reset the control-plane node.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

SSHOPTS=(-i /root/.ssh/lab-key -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5)

# Determine participant prefix (e.g. cka-p1) from hostname or existing nodes
cp_host="$(hostname 2>/dev/null || echo cka-p1-cp)"
prefix="${cp_host%-cp}"
if [[ "$prefix" == "$cp_host" ]]; then
  prefix="cka-p1"
fi

w1_name="${W1_NAME:-${prefix}-w1}"
w2_name="${W2_NAME:-${prefix}-w2}"

resolve_worker_ip() {
  local node="$1" ip=""
  ip="$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)"
  if [[ -z "$ip" ]]; then
    ip="$node"
  fi
  printf '%s' "$ip"
}

w1_target="${W1_HOST:-$(resolve_worker_ip "$w1_name")}"
w2_target="${W2_HOST:-$(resolve_worker_ip "$w2_name")}"

for pair in "${w1_name}:${w1_target}" "${w2_name}:${w2_target}"; do
  w_name="${pair%%:*}"
  w_ip="${pair#*:}"
  printf '==> Resetting worker %s (%s)\n' "$w_name" "$w_ip"
  # containerd 2.x dies if /etc/cni/net.d disappears — empty it, never delete it.
  if ssh "${SSHOPTS[@]}" "root@${w_ip}" 'kubeadm reset -f >/dev/null 2>&1 || true
mkdir -p /etc/cni/net.d; find /etc/cni/net.d -mindepth 1 -delete 2>/dev/null || true
rm -rf /var/lib/cni/networks /etc/kubernetes/kubelet.conf /etc/kubernetes/pki/ca.crt
for _ in $(seq 1 30); do crictl --timeout=2s ps >/dev/null 2>&1 && break; sleep 1; done'; then
    printf 'Worker %s reset via SSH\n' "$w_name"
  else
    printf 'WARN: could not reach root@%s over SSH; ensure kubeadm reset -f is run on %s\n' "$w_ip" "$w_name" >&2
  fi
  kubectl delete node "$w_name" --ignore-not-found >/dev/null 2>&1 || true
done

exit 0
