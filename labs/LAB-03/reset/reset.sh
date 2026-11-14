#!/usr/bin/env bash
# LAB-03 reset: tear down kubeadm state on the control-plane node so LAB-03 can be re-run cleanly.
# NOTE: If the cluster needs to be restored to a full 3-node running state (or if the machine is still
# broken), the trainer can run `lab-cluster.sh init pN` from the trainer workstation.
# This script deliberately does NOT call `lab-cluster.sh init pN` automatically.
set -uo pipefail

printf '==> Running kubeadm reset -f on control-plane node\n'
kubeadm reset -f >/dev/null 2>&1 || true

# containerd 2.x fatals with "cni conf dir is removed, stop watching" when /etc/cni/net.d
# itself disappears, leaving kubeadm init failing with "connection refused" on the CRI socket.
# Empty the directory, never delete it.
mkdir -p /etc/cni/net.d
find /etc/cni/net.d -mindepth 1 -delete 2>/dev/null || true
rm -rf /etc/kubernetes /var/lib/etcd /var/lib/cni/networks /root/.kube/config

# kubeadm reset restarts containerd; wait until the CRI socket answers before kubeadm init.
for _ in $(seq 1 30); do
  if crictl --timeout=2s ps >/dev/null 2>&1; then break; fi
  sleep 1
done

printf '==> Control plane reset complete.\n'
printf 'NOTE: If the machine is still broken or you need to restore the full cluster, run from the trainer host:\n'
printf '  ./lab-cluster.sh init pN\n'
exit 0
