#!/usr/bin/env bash
# LAB-05 verifier: Maintenance (cordon/drain/uncordon) & etcd backup/restore
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

SNAP_FILE="${SNAP_FILE:-/root/lab/etcd-snap.db}"
RESTORE_DIR="${RESTORE_DIR:-/root/lab/etcd-restore}"

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

# 1. Worker node cka-pN-w1 exists and is schedulable (spec.unschedulable absent/false)
w1_node="$(kubectl get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E '^cka-p[0-9]+-w1$' | head -1)"
if [[ -n "$w1_node" ]]; then
  unsched="$(kubectl get node "$w1_node" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)"
  if [[ -z "$unsched" || "$unsched" == "false" ]]; then
    pass "node '${w1_node}' exists and is schedulable (spec.unschedulable='${unsched:-absent}', expected: absent)"
  else
    fail "node '${w1_node}' is still cordoned (spec.unschedulable='${unsched}', expected: absent)"
  fi
else
  fail "worker node matching 'cka-pN-w1' not found in cluster (expected: node present and schedulable)"
fi

# 2. /root/lab/etcd-snap.db exists and is non-empty
if [[ -s "$SNAP_FILE" ]]; then
  snap_size="$(wc -c < "$SNAP_FILE" 2>/dev/null | tr -d '[:space:]')"
  pass "etcd snapshot file '${SNAP_FILE}' exists and is non-empty (${snap_size} bytes, expected: >0 bytes)"
else
  fail "etcd snapshot file '${SNAP_FILE}' is missing or empty (expected: non-empty file)"
fi

# 3. etcdutl snapshot status succeeds and prints a hash
status_out="$(etcdutl snapshot status "$SNAP_FILE" -w table 2>/dev/null || true)"
hash_val="$(printf '%s\n' "$status_out" | awk -F'|' 'tolower($0) ~ /[0-9a-f]{6,}/ {gsub(/[[:space:]]/, "", $2); if ($2 ~ /^[0-9a-f]+$/) {print $2; exit}}')"
if [[ -n "$hash_val" ]]; then
  pass "etcdutl snapshot status on '${SNAP_FILE}' succeeded with hash '${hash_val}' (expected: valid hex hash)"
elif [[ -n "$status_out" ]] && printf '%s\n' "$status_out" | grep -Eiq '[0-9a-f]{6,}'; then
  pass "etcdutl snapshot status on '${SNAP_FILE}' succeeded and printed a hash (expected: valid status table)"
else
  fail "etcdutl snapshot status on '${SNAP_FILE}' failed or produced no hash (expected: valid snapshot status output)"
fi

# 4. /root/lab/etcd-restore/member/snap exists
if [[ -d "${RESTORE_DIR}/member/snap" ]]; then
  pass "restored etcd directory '${RESTORE_DIR}/member/snap' exists (expected: directory present)"
else
  fail "restored etcd directory '${RESTORE_DIR}/member/snap' is missing (expected: directory present)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
