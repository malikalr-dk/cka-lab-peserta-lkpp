#!/usr/bin/env bash
# LAB-03 verifier: kubeadm init (control plane initialized, CNI not required yet)
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

ADMIN_CONF="${ADMIN_CONF:-/etc/kubernetes/admin.conf}"
ROOT_KUBECONFIG="${ROOT_KUBECONFIG:-/root/.kube/config}"

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG="$ROOT_KUBECONFIG"
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

passed=0
total=0

pass() {
  passed=$((passed + 1))
  total=$((total + 1))
  printf 'PASS: %s\n' "$*"
}

fail() {
  total=$((total + 1))
  printf 'FAIL: %s\n' "$*"
}

# 1. /etc/kubernetes/admin.conf exists
if [[ -f "$ADMIN_CONF" ]]; then
  pass "admin kubeconfig '${ADMIN_CONF}' exists (expected: file present)"
else
  fail "admin kubeconfig '${ADMIN_CONF}' is missing (expected: file present)"
fi

# 2. /root/.kube/config exists
if [[ -f "$ROOT_KUBECONFIG" ]]; then
  pass "root kubeconfig '${ROOT_KUBECONFIG}' exists (expected: file present)"
else
  fail "root kubeconfig '${ROOT_KUBECONFIG}' is missing (expected: file present)"
fi

# 3. kubectl get --raw /healthz returns ok
healthz_out="$(kubectl get --raw /healthz 2>/dev/null || true)"
if [[ "$healthz_out" == "ok" ]]; then
  pass "API server health endpoint '/healthz' returned '${healthz_out}' (expected: 'ok')"
else
  fail "API server health endpoint '/healthz' returned '${healthz_out:-error}' (expected: 'ok')"
fi

# 4. API server container is running (crictl is a golden-image prerequisite)
if ! command -v crictl >/dev/null 2>&1; then
  fail "crictl is not installed, cannot inspect the API server container (expected: crictl present on the golden image)"
elif crictl ps 2>/dev/null | awk '$0 ~ /kube-apiserver/ && $0 ~ /Running/ {found=1} END {exit !found}'; then
  pass "container 'kube-apiserver' state is Running (expected: Running)"
else
  fail "container 'kube-apiserver' is not Running in CRI (expected: Running)"
fi

# 5. kubectl get nodes shows the CP in Ready or NotReady (CNI comes in LAB-04)
nodes_out="$(kubectl get nodes --no-headers 2>/dev/null || true)"
cp_line="$(printf '%s\n' "$nodes_out" | awk '$1 ~ /^cka-p[0-9]+-cp$/ || $3 ~ /control-plane/ {print $1, $2; exit}')"
cp_name="${cp_line%% *}"
cp_status="${cp_line#* }"

if [[ -n "$cp_name" && ( "$cp_status" == "Ready" || "$cp_status" == "NotReady" ) ]]; then
  pass "control-plane node '${cp_name}' status is '${cp_status}' (expected: 'Ready' or 'NotReady'; CNI comes in LAB-04)"
else
  fail "control-plane node 'cka-pN-cp' status is '${cp_status:-absent}' (expected: 'Ready' or 'NotReady')"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
