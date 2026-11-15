#!/usr/bin/env bash
# LAB-08 verifier: ConfigMaps, Secrets, and scheduling constraints (nodeSelector, taint/toleration)
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="gisp-app"

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

w1_node="$(kubectl get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E '^cka-p[0-9]+-w1$' | head -1)"
w2_node="$(kubectl get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E '^cka-p[0-9]+-w2$' | head -1)"

# 1. Pod config-demo is Running in gisp-app
cfg_phase="$(kubectl -n "$NS" get pod config-demo -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ "$cfg_phase" == "Running" ]]; then
  pass "Pod '${NS}/config-demo' phase is '${cfg_phase}' (expected: 'Running')"
else
  fail "Pod '${NS}/config-demo' phase is '${cfg_phase:-absent}' (expected: 'Running')"
fi

# 2. kubectl exec prints env GREETING=halo-cka
greeting_val="$(kubectl -n "$NS" exec config-demo -- sh -c 'printf "%s" "${GREETING:-}"' 2>/dev/null || true)"
if [[ "$greeting_val" == "halo-cka" ]]; then
  pass "Pod '${NS}/config-demo' env GREETING is '${greeting_val}' (expected: 'halo-cka')"
else
  fail "Pod '${NS}/config-demo' env GREETING is '${greeting_val:-empty}' (expected: 'halo-cka')"
fi

# 3. Mounted file /etc/app/app.properties exists and contains known token
prop_content="$(kubectl -n "$NS" exec config-demo -- sh -c 'cat /etc/app/app.properties' 2>/dev/null || true)"
cm_prop="$(kubectl -n "$NS" get configmap app-config -o jsonpath='{.data.app\.properties}' 2>/dev/null || true)"
if [[ -n "$prop_content" ]] && (printf '%s\n' "$prop_content" | grep -Eq 'mode=production|=' || [[ "$prop_content" == "$cm_prop" ]]); then
  first_line="$(printf '%s\n' "$prop_content" | head -1 | tr -d '\r')"
  pass "Pod '${NS}/config-demo' mounted file '/etc/app/app.properties' exists and contains '${first_line}' (expected: non-empty properties content)"
else
  fail "Pod '${NS}/config-demo' mounted file '/etc/app/app.properties' is missing or empty (expected: file present with properties token)"
fi

# 4. env PASSWORD matches Secret app-secret's value (s3cr3t)
pw_val="$(kubectl -n "$NS" exec config-demo -- sh -c 'printf "%s" "${PASSWORD:-}"' 2>/dev/null || true)"
if [[ "$pw_val" == "s3cr3t" ]]; then
  pass "Pod '${NS}/config-demo' env PASSWORD matches Secret 'app-secret' value 's3cr3t' (expected: 's3cr3t')"
else
  fail "Pod '${NS}/config-demo' env PASSWORD is '${pw_val:-empty}' (expected: 's3cr3t')"
fi

# 5. Pod sched-demo spec.nodeName is cka-pN-w1
sched_node="$(kubectl -n "$NS" get pod sched-demo -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)"
sched_phase="$(kubectl -n "$NS" get pod sched-demo -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ -n "$w1_node" && "$sched_node" == "$w1_node" && "$sched_phase" == "Running" ]]; then
  pass "Pod '${NS}/sched-demo' is Running on node '${sched_node}' (expected: '${w1_node}')"
else
  fail "Pod '${NS}/sched-demo' is on node '${sched_node:-none}' with phase '${sched_phase:-absent}' (expected: Running on '${w1_node:-cka-pN-w1}')"
fi

# 6. Pod taint-demo spec.nodeName is cka-pN-w2
taint_node="$(kubectl -n "$NS" get pod taint-demo -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)"
taint_phase="$(kubectl -n "$NS" get pod taint-demo -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ -n "$w2_node" && "$taint_node" == "$w2_node" && "$taint_phase" == "Running" ]]; then
  pass "Pod '${NS}/taint-demo' is Running on node '${taint_node}' (expected: '${w2_node}')"
else
  fail "Pod '${NS}/taint-demo' is on node '${taint_node:-none}' with phase '${taint_phase:-absent}' (expected: Running on '${w2_node:-cka-pN-w2}')"
fi

# 7. Taint dedicated=lab:NoSchedule exists on cka-pN-w2
if [[ -n "$w2_node" ]]; then
  taints_out="$(kubectl get node "$w2_node" -o jsonpath='{range .spec.taints[*]}{.key}={.value}:{.effect}{"\n"}{end}' 2>/dev/null || true)"
  if printf '%s\n' "$taints_out" | grep -Fxq "dedicated=lab:NoSchedule"; then
    pass "node '${w2_node}' has taint 'dedicated=lab:NoSchedule' (expected: 'dedicated=lab:NoSchedule')"
  else
    fail "node '${w2_node}' taints '${taints_out:-none}' do not include 'dedicated=lab:NoSchedule' (expected: 'dedicated=lab:NoSchedule')"
  fi
else
  fail "worker node 'cka-pN-w2' not found when checking taint 'dedicated=lab:NoSchedule'"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
