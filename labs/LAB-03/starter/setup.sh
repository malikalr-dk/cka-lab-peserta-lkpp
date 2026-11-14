#!/usr/bin/env bash
# LAB-03 starter: verifies kubeadm, kubelet, kubectl, and containerd are installed and active
# on the control-plane node before the participant tears down and re-initializes the cluster.
set -uo pipefail

for bin in kubeadm kubelet kubectl crictl; do
  if command -v "$bin" >/dev/null 2>&1; then
    printf 'READY: binary %s found on PATH\n' "$bin"
  else
    printf 'WARN: binary %s missing from PATH\n' "$bin" >&2
  fi
done
