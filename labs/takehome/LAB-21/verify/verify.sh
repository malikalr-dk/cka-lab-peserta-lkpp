#!/usr/bin/env bash
# LAB-21 verifier (take-home): Kustomize base + dev/prod overlays applied to the cluster.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG tidak diset; memakai %s\n' "$KUBECONFIG"
fi

NS_DEV="lab21"
NS_PROD="lab21-prod"
REPORT="/root/lab21/report.txt"
passed=0
total=0

pass() { passed=$((passed + 1)); total=$((total + 1)); printf 'PASS: %s\n' "$*"; }
fail() { total=$((total + 1)); printf 'FAIL: %s\n' "$*"; }

# 1. Overlay dev: Deployment dev-web 1 replika, Ready
printf 'INFO: menunggu %s/dev-web Ready (maks 45s)...\n' "$NS_DEV"
dev_ready=0
for _ in $(seq 1 15); do
  dev_ready="$(kubectl -n "$NS_DEV" get deployment dev-web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "${dev_ready:-0}" -eq 1 ]] && break
  sleep 3
done
dev_spec="$(kubectl -n "$NS_DEV" get deployment dev-web -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
dev_env="$(kubectl -n "$NS_DEV" get deployment dev-web -o jsonpath='{.metadata.labels.env}' 2>/dev/null || true)"
if [[ "${dev_spec:-0}" == "1" && "${dev_ready:-0}" -eq 1 && "$dev_env" == "dev" ]]; then
  pass "Deployment '${NS_DEV}/dev-web' has replicas=${dev_ready}/${dev_spec} and label env='${dev_env}' (expected: 1/1, env=dev)"
else
  fail "Deployment '${NS_DEV}/dev-web' has replicas=${dev_ready:-0}/${dev_spec:-0}, label env='${dev_env:-missing}' (expected: 1/1, env=dev)"
fi

# 2. Overlay prod: Deployment prod-web 3 replika, Ready
printf 'INFO: menunggu %s/prod-web Ready (maks 60s)...\n' "$NS_PROD"
prod_ready=0
for _ in $(seq 1 20); do
  prod_ready="$(kubectl -n "$NS_PROD" get deployment prod-web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "${prod_ready:-0}" -eq 3 ]] && break
  sleep 3
done
prod_spec="$(kubectl -n "$NS_PROD" get deployment prod-web -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
prod_env="$(kubectl -n "$NS_PROD" get deployment prod-web -o jsonpath='{.metadata.labels.env}' 2>/dev/null || true)"
if [[ "${prod_spec:-0}" == "3" && "${prod_ready:-0}" -eq 3 && "$prod_env" == "prod" ]]; then
  pass "Deployment '${NS_PROD}/prod-web' has replicas=${prod_ready}/${prod_spec} and label env='${prod_env}' (expected: 3/3, env=prod)"
else
  fail "Deployment '${NS_PROD}/prod-web' has replicas=${prod_ready:-0}/${prod_spec:-0}, label env='${prod_env:-missing}' (expected: 3/3, env=prod)"
fi

# 3. Patch prod: limits.cpu=200m, dev tanpa limits
prod_lim="$(kubectl -n "$NS_PROD" get deployment prod-web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || true)"
dev_lim="$(kubectl -n "$NS_DEV" get deployment dev-web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || true)"
if [[ "$prod_lim" == "200m" && -z "$dev_lim" ]]; then
  pass "Overlay patch applied: prod limits.cpu='${prod_lim}', dev limits.cpu='${dev_lim:-none}' (expected: 200m, none)"
else
  fail "Overlay patch mismatch: prod limits.cpu='${prod_lim:-none}', dev limits.cpu='${dev_lim:-none}' (expected: 200m, none)"
fi

# 4. Namespace dari overlay dipakai, bukan default
dev_ns_ok=0
kubectl -n "$NS_DEV" get configmap dev-web-config >/dev/null 2>&1 && dev_ns_ok=1
prod_ns_ok=0
kubectl -n "$NS_PROD" get configmap prod-web-config >/dev/null 2>&1 && prod_ns_ok=1
if [[ "$dev_ns_ok" -eq 1 && "$prod_ns_ok" -eq 1 ]]; then
  pass "Overlay namespace dipakai: '${NS_DEV}/dev-web-config' dan '${NS_PROD}/prod-web-config' ada (expected: keduanya ada)"
else
  fail "Overlay namespace salah: dev=${dev_ns_ok}, prod=${prod_ns_ok} (expected: keduanya ada)"
fi

# 5. Laporan
rep_prod=""
if [[ -f "$REPORT" ]]; then
  rep_prod="$(awk -F= '/^kustomize_prod_replicas=/{print $2; exit}' "$REPORT" | tr -d '\r')"
fi
if [[ "$rep_prod" == "3" && "$prod_spec" == "3" ]]; then
  pass "Report '${REPORT}' has kustomize_prod_replicas=${rep_prod} matching live prod-web=${prod_spec} (expected: 3)"
else
  fail "Report '${REPORT}' has kustomize_prod_replicas='${rep_prod:-missing}', live prod-web=${prod_spec:-0} (expected: 3)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
fi
printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
exit 1
