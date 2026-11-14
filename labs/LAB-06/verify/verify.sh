#!/usr/bin/env bash
# LAB-06 verifier: RBAC (ServiceAccount, Role, RoleBinding, ClusterRole, ClusterRoleBinding)
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="cka-lab06"
SA_NAME="dev-sa"
SA_USER="system:serviceaccount:${NS}:${SA_NAME}"

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

# 1. ServiceAccount dev-sa exists in cka-lab06
if kubectl -n "$NS" get sa "$SA_NAME" >/dev/null 2>&1; then
  pass "ServiceAccount '${NS}/${SA_NAME}' exists (expected: present)"
else
  fail "ServiceAccount '${NS}/${SA_NAME}' does not exist (expected: present)"
fi

# 2. can-i list pods -n cka-lab06 -> yes
ans="$(kubectl auth can-i list pods -n "$NS" --as="$SA_USER" 2>/dev/null | tr -d '[:space:]' || true)"
if [[ "$ans" == "yes" ]]; then
  pass "auth can-i 'list pods -n ${NS}' as '${SA_USER}' returned '${ans}' (expected: 'yes')"
else
  fail "auth can-i 'list pods -n ${NS}' as '${SA_USER}' returned '${ans:-error}' (expected: 'yes')"
fi

# 3. can-i delete pods -n cka-lab06 -> no
ans="$(kubectl auth can-i delete pods -n "$NS" --as="$SA_USER" 2>/dev/null | tr -d '[:space:]' || true)"
if [[ "$ans" == "no" ]]; then
  pass "auth can-i 'delete pods -n ${NS}' as '${SA_USER}' returned '${ans}' (expected: 'no')"
else
  fail "auth can-i 'delete pods -n ${NS}' as '${SA_USER}' returned '${ans:-error}' (expected: 'no')"
fi

# 4. can-i list pods -n default -> no
ans="$(kubectl auth can-i list pods -n default --as="$SA_USER" 2>/dev/null | tr -d '[:space:]' || true)"
if [[ "$ans" == "no" ]]; then
  pass "auth can-i 'list pods -n default' as '${SA_USER}' returned '${ans}' (expected: 'no')"
else
  fail "auth can-i 'list pods -n default' as '${SA_USER}' returned '${ans:-error}' (expected: 'no')"
fi

# 5. can-i list nodes -> yes
ans="$(kubectl auth can-i list nodes --as="$SA_USER" 2>/dev/null | tr -d '[:space:]' || true)"
if [[ "$ans" == "yes" ]]; then
  pass "auth can-i 'list nodes' as '${SA_USER}' returned '${ans}' (expected: 'yes')"
else
  fail "auth can-i 'list nodes' as '${SA_USER}' returned '${ans:-error}' (expected: 'yes')"
fi

# 6. can-i get secrets -n cka-lab06 -> no
ans="$(kubectl auth can-i get secrets -n "$NS" --as="$SA_USER" 2>/dev/null | tr -d '[:space:]' || true)"
if [[ "$ans" == "no" ]]; then
  pass "auth can-i 'get secrets -n ${NS}' as '${SA_USER}' returned '${ans}' (expected: 'no')"
else
  fail "auth can-i 'get secrets -n ${NS}' as '${SA_USER}' returned '${ans:-error}' (expected: 'no')"
fi

# 7. Role in cka-lab06 exists and its rules do not use '*' verbs or '*' resources
role_names="$(kubectl -n "$NS" get role -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
role_verbs="$(kubectl -n "$NS" get role -o jsonpath='{.items[*].rules[*].verbs[*]}' 2>/dev/null || true)"
role_resources="$(kubectl -n "$NS" get role -o jsonpath='{.items[*].rules[*].resources[*]}' 2>/dev/null || true)"

has_wildcard=0
for tok in $role_verbs $role_resources; do
  if [[ "$tok" == "*" ]]; then
    has_wildcard=1
  fi
done

if [[ -n "$role_names" && "$has_wildcard" -eq 0 ]]; then
  pass "Role(s) '${role_names}' in '${NS}' define explicit verbs/resources without '*' wildcards (expected: no '*')"
elif [[ -z "$role_names" ]]; then
  fail "no Role found in namespace '${NS}' (expected: Role present without '*' verbs/resources)"
else
  fail "Role(s) '${role_names}' in '${NS}' contain wildcard '*' in verbs or resources (expected: no '*')"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
