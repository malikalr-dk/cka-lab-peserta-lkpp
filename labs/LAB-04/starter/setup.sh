#!/usr/bin/env bash
# LAB-04 starter: confirm control-plane is initialized from LAB-03 and local Calico manifest exists.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

if [[ -f /etc/kubernetes/admin.conf ]]; then
  printf 'READY: /etc/kubernetes/admin.conf present\n'
else
  printf 'WARN: /etc/kubernetes/admin.conf missing (complete LAB-03 first)\n' >&2
fi

if [[ -f /opt/lab/manifests/calico.yaml ]]; then
  printf 'READY: /opt/lab/manifests/calico.yaml present\n'
else
  printf 'WARN: /opt/lab/manifests/calico.yaml missing\n' >&2
fi
