#!/usr/bin/env bash
# LAB-01 starter: ensure /root/lab exists, namespace lab01 is absent, and cached nginx images
# are present in containerd via crictl images.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="lab01"
LAB_DIR="/root/lab"

mkdir -p "$LAB_DIR"
rm -f "${LAB_DIR}/lab01-pod.yaml" "${LAB_DIR}/lab01-report.txt"

if kubectl get namespace "$NS" >/dev/null 2>&1; then
  printf 'INFO: deleting existing namespace %s...\n' "$NS"
  kubectl delete namespace "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  for _ in $(seq 1 30); do
    if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
fi

if kubectl cluster-info >/dev/null 2>&1; then
  printf 'READY: Kubernetes API server is reachable\n'
else
  printf 'WARN: Kubernetes API server is not reachable via KUBECONFIG=%s\n' "$KUBECONFIG"
fi

if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
  printf 'READY: namespace %s is absent (clean initial state)\n' "$NS"
else
  printf 'WARN: namespace %s still exists (terminating)\n' "$NS"
fi

printf 'READY: working directory %s is prepared\n' "$LAB_DIR"

cri_out="$(crictl images 2>/dev/null || true)"
if printf '%s\n' "$cri_out" | grep -q 'nginx.*1\.27-alpine'; then
  printf 'READY: image nginx:1.27-alpine present in CRI cache (crictl images)\n'
else
  printf 'WARN: image nginx:1.27-alpine not found in crictl images output\n'
fi

if printf '%s\n' "$cri_out" | grep -q 'nginx.*1\.29-alpine'; then
  printf 'READY: image nginx:1.29-alpine present in CRI cache (crictl images)\n'
else
  printf 'WARN: image nginx:1.29-alpine not found in crictl images output\n'
fi

printf 'READY: LAB-01 starter pre-flight complete\n'
