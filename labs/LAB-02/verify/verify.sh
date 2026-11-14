#!/usr/bin/env bash
# LAB-02 verifier: Cluster architecture inspection (read-only)
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

REPORT_FILE="${REPORT_FILE:-/root/lab/lab02-report.txt}"

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

# 1. kubectl get nodes shows 3 Ready
nodes_out="$(kubectl get nodes --no-headers 2>/dev/null || true)"
ready_count="$(printf '%s\n' "$nodes_out" | awk '$2 == "Ready" {count++} END {print count+0}')"
if [[ "$ready_count" -eq 3 ]]; then
  pass "kubectl get nodes shows ${ready_count} Ready nodes (expected: 3)"
else
  fail "kubectl get nodes shows ${ready_count} Ready nodes (expected: 3)"
fi

# 2-7. kube-system pods: etcd, kube-apiserver, kube-controller-manager, kube-scheduler, coredns, calico-node
pods_out="$(kubectl -n kube-system get pods --no-headers 2>/dev/null || true)"
for comp in etcd kube-apiserver kube-controller-manager kube-scheduler coredns calico-node; do
  if printf '%s\n' "$pods_out" | awk -v c="$comp" '$1 ~ "^"c && $3 == "Running" {found=1} END {exit !found}'; then
    pass "kube-system component '${comp}' has Running pod (expected: Running)"
  else
    fail "kube-system component '${comp}' has no Running pod (expected: Running)"
  fi
done

# 8. Report file exists
if [[ -f "$REPORT_FILE" ]]; then
  pass "report file '${REPORT_FILE}' exists (expected: file present)"
else
  fail "report file '${REPORT_FILE}' does not exist (expected: file present)"
fi

# 9-12. Report file contains the four control-plane component names
for comp in etcd kube-apiserver kube-controller-manager kube-scheduler; do
  if [[ -f "$REPORT_FILE" ]] && grep -q "$comp" "$REPORT_FILE" 2>/dev/null; then
    pass "report file '${REPORT_FILE}' contains control-plane component '${comp}' (expected: '${comp}')"
  else
    fail "report file '${REPORT_FILE}' is missing control-plane component '${comp}' (expected: '${comp}')"
  fi
done

# 13. Report file contains the API server endpoint
api_server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"
api_hostport="${api_server#https://}"
if [[ -f "$REPORT_FILE" ]]; then
  if [[ -n "$api_server" ]] && (grep -Fq "$api_server" "$REPORT_FILE" 2>/dev/null || grep -Fq "$api_hostport" "$REPORT_FILE" 2>/dev/null); then
    pass "report file '${REPORT_FILE}' contains API server endpoint '${api_server}' (expected: '${api_server}')"
  elif grep -Eq 'https://[^[:space:]]+:6443|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:6443' "$REPORT_FILE" 2>/dev/null; then
    matched_ep="$(grep -Eo 'https://[^[:space:]]+:6443|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:6443' "$REPORT_FILE" | head -1)"
    pass "report file '${REPORT_FILE}' contains API server endpoint '${matched_ep}' (expected: '<host>:6443')"
  else
    fail "report file '${REPORT_FILE}' is missing API server endpoint (expected: '${api_server:-https://<cp-ip>:6443}')"
  fi
else
  fail "report file '${REPORT_FILE}' is missing API server endpoint because file does not exist (expected: '${api_server:-https://<cp-ip>:6443}')"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
