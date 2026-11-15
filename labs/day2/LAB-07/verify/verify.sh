#!/usr/bin/env bash
# LAB-07 verifier: Deployments (rolling update, rollback, self-healing)
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="cka-lab07"
DEPLOY="web"

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

# 1. Deployment 'web' exists in cka-lab07
if kubectl -n "$NS" get deployment "$DEPLOY" >/dev/null 2>&1; then
  pass "Deployment '${NS}/${DEPLOY}' exists (expected: present)"
else
  fail "Deployment '${NS}/${DEPLOY}' does not exist (expected: present)"
fi

# 2. spec.replicas == 3 and status.readyReplicas == 3
spec_rep="$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
ready_rep="$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
if [[ "$spec_rep" == "3" && "$ready_rep" == "3" ]]; then
  pass "Deployment '${NS}/${DEPLOY}' has spec.replicas=${spec_rep} and readyReplicas=${ready_rep} (expected: 3 and 3)"
else
  fail "Deployment '${NS}/${DEPLOY}' has spec.replicas=${spec_rep:-0} and readyReplicas=${ready_rep:-0} (expected: 3 and 3)"
fi

# 3. strategy.rollingUpdate.maxUnavailable == 1 and maxSurge == 1
max_unavail="$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null || true)"
max_surge="$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' 2>/dev/null || true)"
if [[ "$max_unavail" == "1" && "$max_surge" == "1" ]]; then
  pass "Deployment '${NS}/${DEPLOY}' rollingUpdate strategy has maxUnavailable=${max_unavail}, maxSurge=${max_surge} (expected: 1, 1)"
else
  fail "Deployment '${NS}/${DEPLOY}' rollingUpdate strategy has maxUnavailable=${max_unavail:-unset}, maxSurge=${max_surge:-unset} (expected: 1, 1)"
fi

# 4. All 3 pods are Running
pod_phases="$(kubectl -n "$NS" get pods -l app=web -o jsonpath='{.items[*].status.phase}' 2>/dev/null || true)"
running_count=0
for ph in $pod_phases; do
  if [[ "$ph" == "Running" ]]; then
    running_count=$((running_count + 1))
  fi
done
if [[ "$running_count" -eq 3 ]]; then
  pass "Deployment '${NS}/${DEPLOY}' has ${running_count} Running pods (expected: 3)"
else
  fail "Deployment '${NS}/${DEPLOY}' has ${running_count} Running pods (expected: 3)"
fi

# 5. All pods are owned by a web ReplicaSet
owners="$(kubectl -n "$NS" get pods -l app=web -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].kind}:{.metadata.ownerReferences[0].name}{"\n"}{end}' 2>/dev/null || true)"
owned_count=0
for own in $owners; do
  if [[ "$own" =~ ^ReplicaSet:web- ]]; then
    owned_count=$((owned_count + 1))
  fi
done
if [[ "$owned_count" -eq 3 ]]; then
  pass "all ${owned_count} pods in '${NS}' are owned by a '${DEPLOY}' ReplicaSet (expected: 3)"
else
  fail "only ${owned_count} pods in '${NS}' are owned by a '${DEPLOY}' ReplicaSet (expected: 3)"
fi

# 6. Running image is nginx:1.27-alpine (post-rollback state)
dep_img="$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
pod_imgs="$(kubectl -n "$NS" get pods -l app=web -o jsonpath='{.items[*].spec.containers[0].image}' 2>/dev/null || true)"
img_ok=1
if [[ "$dep_img" != "nginx:1.27-alpine" && "$dep_img" != "docker.io/library/nginx:1.27-alpine" ]]; then
  img_ok=0
fi
for pi in $pod_imgs; do
  if [[ "$pi" != "nginx:1.27-alpine" && "$pi" != "docker.io/library/nginx:1.27-alpine" ]]; then
    img_ok=0
  fi
done
if [[ "$img_ok" -eq 1 && -n "$pod_imgs" ]]; then
  pass "Deployment '${NS}/${DEPLOY}' and its pods run image '${dep_img}' (expected: 'nginx:1.27-alpine')"
else
  fail "Deployment '${NS}/${DEPLOY}' image is '${dep_img:-none}' (pods: '${pod_imgs:-none}', expected: 'nginx:1.27-alpine')"
fi

# 7. Rollout history has >= 2 revisions
history_out="$(kubectl -n "$NS" rollout history deployment/"$DEPLOY" 2>/dev/null || true)"
rev_count="$(printf '%s\n' "$history_out" | awk '$1 ~ /^[0-9]+$/ {c++} END {print c+0}')"
if [[ "$rev_count" -ge 2 ]]; then
  pass "Deployment '${NS}/${DEPLOY}' rollout history has ${rev_count} revisions (expected: >=2)"
else
  fail "Deployment '${NS}/${DEPLOY}' rollout history has ${rev_count} revisions (expected: >=2)"
fi

# 8. Self-healing proof: at least one pod has creationTimestamp strictly later than the Deployment's creationTimestamp
dep_ts="$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || true)"
pod_ts_list="$(kubectl -n "$NS" get pods -l app=web -o jsonpath='{.items[*].metadata.creationTimestamp}' 2>/dev/null || true)"
newer_pod_ts=""
for pts in $pod_ts_list; do
  if [[ -n "$dep_ts" && "$pts" > "$dep_ts" ]]; then
    newer_pod_ts="$pts"
  fi
done
if [[ -n "$newer_pod_ts" ]]; then
  pass "self-healing verified: pod created at '${newer_pod_ts}' is newer than Deployment creationTimestamp '${dep_ts}'"
else
  fail "no pod found with creationTimestamp newer than Deployment '${dep_ts:-none}' (expected: pod created after starter apply)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
