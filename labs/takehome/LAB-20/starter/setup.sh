#!/usr/bin/env bash
# LAB-20 starter:
# Part A: install CRD configforges.lab.example.com (with spec.data maxLength=40 validation)
# Part B: install/upgrade Traefik from /opt/lab/charts/traefik-42.4.0.tgz with CRD provider enabled
#         on NodePort 30082, ensure ingressroutes.traefik.io CRD is Established, and create
#         namespace cka-lab20 with Deployment web (nginx:1.27-alpine, 1 replica) and Service web.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab20"
TRAEFIK_NS="traefik"
CRD_NAME="configforges.lab.example.com"
CHART="/opt/lab/charts/traefik-42.4.0.tgz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
MANIFESTS="${SCRIPT_DIR}/manifests.yaml"
# `bash -s < setup.sh` (the documented remote runner) makes BASH_SOURCE /dev/stdin, so
# SCRIPT_DIR resolves to /dev and the whole manifests.yaml (CRD ConfigForge + web) was skipped
# silently while the script still printed READY.
if [[ ! -f "$MANIFESTS" ]]; then
  MANIFESTS="/opt/lab/labs/LAB-20/starter/manifests.yaml"
fi
if [[ ! -f "$MANIFESTS" ]]; then
  printf 'FAIL: starter/manifests.yaml tidak ditemukan (script_dir=%s)\n' "${SCRIPT_DIR:-?}" >&2
  exit 1
fi

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete crd "$CRD_NAME" --ignore-not-found >/dev/null 2>&1 || true
# A terminating namespace still answers 'create' with AlreadyExists; wait for it to be gone.
for _ in $(seq 1 60); do
  kubectl get namespace "$NS" >/dev/null 2>&1 || break
  sleep 2
done
kubectl create namespace "$NS" >/dev/null

# Apply ConfigForge CRD, Traefik fallback CRDs + RBAC, and web Deployment/Service in cka-lab20
if ! kubectl apply -f "$MANIFESTS" >/dev/null; then
  printf 'FAIL: kubectl apply %s gagal\n' "$MANIFESTS" >&2
  exit 1
fi

printf 'INFO: installing/updating Traefik with CRD provider enabled in namespace %s (NodePort 30082)...\n' "$TRAEFIK_NS"
if ! helm upgrade --install traefik "$CHART" \
  -n "$TRAEFIK_NS" --create-namespace \
  --set providers.kubernetesCRD.enabled=true \
  --set ports.web.port=80 \
  --set ports.web.exposedPort=80 \
  --set ports.web.nodePort=30082 \
  --set image.pullPolicy=IfNotPresent \
  --set service.spec.type=NodePort >/dev/null 2>&1; then
  printf 'FAIL: helm upgrade Traefik gagal di %s — menampilkan log error:\n' "$TRAEFIK_NS" >&2
  helm upgrade --install traefik "$CHART" \
    -n "$TRAEFIK_NS" --create-namespace \
    --set providers.kubernetesCRD.enabled=true \
    --set ports.web.port=80 \
    --set ports.web.exposedPort=80 \
    --set ports.web.nodePort=30082 \
    --set image.pullPolicy=IfNotPresent \
    --set service.spec.type=NodePort 2>&1 | tail -5 >&2 || exit 1
fi

# Re-apply manifests.yaml in case helm upgrade skipped CRDs or RBAC on an existing release
kubectl apply -f "$MANIFESTS" >/dev/null 2>&1 || true

printf 'INFO: waiting up to 30s for CRDs %s and ingressroutes.traefik.io to be Established...\n' "$CRD_NAME"
crd_ok=0
for _ in $(seq 1 15); do
  cf_est="$(kubectl get crd "$CRD_NAME" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  ir_est="$(kubectl get crd ingressroutes.traefik.io -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  if [[ "$cf_est" == *"Established=True"* && "$ir_est" == *"Established=True"* ]]; then
    crd_ok=1
    break
  fi
  sleep 2
done
if [[ "$crd_ok" -ne 1 ]]; then
  printf 'FAIL: CRD %s (%s) atau ingressroutes.traefik.io (%s) tidak Established=True setelah 30s\n' \
    "$CRD_NAME" "${cf_est:-missing}" "${ir_est:-missing}" >&2
  exit 1
fi

# Ensure no participant custom resources exist at starter time
kubectl -n "$NS" delete configforges.lab.example.com --all --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "$NS" delete ingressroutes.traefik.io --all --ignore-not-found >/dev/null 2>&1 || true

printf 'INFO: waiting up to 90s for Traefik deployment in namespace %s...\n' "$TRAEFIK_NS"
if ! kubectl -n "$TRAEFIK_NS" rollout status deployment/traefik --timeout=90s >/dev/null; then
  printf 'FAIL: Deployment %s/traefik tidak ready setelah 90s — IngressRoute tidak akan direkonsiliasi\n' "$TRAEFIK_NS" >&2
  kubectl -n "$TRAEFIK_NS" get pods >&2 || true
  exit 1
fi

printf 'INFO: waiting up to 60s for Deployment %s/web rollout...\n' "$NS"
if ! kubectl -n "$NS" rollout status deployment/web --timeout=60s >/dev/null; then
  printf 'FAIL: Deployment %s/web tidak ready setelah 60s\n' "$NS" >&2
  kubectl -n "$NS" get pods >&2 || true
  exit 1
fi

printf 'READY: CRD %s, Traefik CRD provider (NodePort 30082), and %s/web initialized for LAB-20\n' "$CRD_NAME" "$NS"
