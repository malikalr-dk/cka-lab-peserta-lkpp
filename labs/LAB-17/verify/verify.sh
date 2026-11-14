#!/usr/bin/env bash
# LAB-17 verifier: Kustomize overlays (dev + prod) and Helm chart lifecycle (install, upgrade, rollback, upgrade)
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS_DEV="lab17"
NS_PROD="lab17-prod"
NS_HELM="lab17-helm"
RELEASE="lab17-web"
REPORT_FILE="/root/lab17/report.txt"

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

# 1. Deployment 'dev-web' in namespace 'lab17' is Running/available with 1 replica and carries env=dev label
dev_ready=""
for _ in $(seq 1 15); do
  dev_ready="$(kubectl -n "$NS_DEV" get deployment dev-web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "${dev_ready:-0}" -eq 1 ]] && break
  sleep 2
done
dev_spec_rep="$(kubectl -n "$NS_DEV" get deployment dev-web -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
dev_env_lbl="$(kubectl -n "$NS_DEV" get deployment dev-web -o jsonpath='{.metadata.labels.env}' 2>/dev/null || true)"
if [[ "${dev_spec_rep:-0}" -eq 1 && "${dev_ready:-0}" -eq 1 && "$dev_env_lbl" == "dev" ]]; then
  pass "Deployment '${NS_DEV}/dev-web' is available with replicas=${dev_spec_rep}, readyReplicas=${dev_ready}, label env=${dev_env_lbl} (expected: 1 ready replica, env=dev)"
else
  fail "Deployment '${NS_DEV}/dev-web' has replicas=${dev_spec_rep:-missing}, readyReplicas=${dev_ready:-0}, label env=${dev_env_lbl:-missing} (expected: 1 ready replica, env=dev)"
fi

# 2. Deployment 'prod-web' from the prod overlay in 'lab17-prod' has 3 ready replicas
prod_ready=""
for _ in $(seq 1 15); do
  prod_ready="$(kubectl -n "$NS_PROD" get deployment prod-web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "${prod_ready:-0}" -eq 3 ]] && break
  sleep 2
done
prod_spec_rep="$(kubectl -n "$NS_PROD" get deployment prod-web -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
if [[ "${prod_spec_rep:-0}" -eq 3 && "${prod_ready:-0}" -eq 3 ]]; then
  pass "Deployment '${NS_PROD}/prod-web' has replicas=${prod_spec_rep} and readyReplicas=${prod_ready} (expected: 3 ready replicas)"
else
  fail "Deployment '${NS_PROD}/prod-web' has replicas=${prod_spec_rep:-missing} and readyReplicas=${prod_ready:-0} (expected: 3 ready replicas)"
fi

# 3. Prod Deployment carries resources.limits.cpu from the patch and dev Deployment does not
prod_limit_cpu="$(kubectl -n "$NS_PROD" get deployment prod-web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || true)"
dev_limit_cpu="$(kubectl -n "$NS_DEV" get deployment dev-web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || true)"
if [[ -n "$prod_limit_cpu" && -z "$dev_limit_cpu" ]]; then
  pass "Overlay resource limits verified: '${NS_PROD}/prod-web' limits.cpu='${prod_limit_cpu}' and '${NS_DEV}/dev-web' limits.cpu is unset (expected: prod has limits.cpu, dev has none)"
else
  fail "Overlay resource limits mismatch: '${NS_PROD}/prod-web' limits.cpu='${prod_limit_cpu:-empty}', '${NS_DEV}/dev-web' limits.cpu='${dev_limit_cpu:-empty}' (expected: prod non-empty, dev empty)"
fi

# 4. 'helm -n lab17-helm status lab17-web' shows STATUS: deployed and revision >= 2
helm_status_out="$(helm -n "$NS_HELM" status "$RELEASE" 2>/dev/null || true)"
helm_status="$(printf '%s\n' "$helm_status_out" | awk -F': ' '/^STATUS:/ {print $2; exit}' | tr -d '[:space:]')"
helm_rev="$(printf '%s\n' "$helm_status_out" | awk -F': ' '/^REVISION:/ {print $2; exit}' | tr -d '[:space:]')"
if [[ "$helm_status" == "deployed" && "${helm_rev:-0}" =~ ^[0-9]+$ && "${helm_rev:-0}" -ge 2 ]]; then
  pass "Helm release '${NS_HELM}/${RELEASE}' has STATUS=${helm_status} and REVISION=${helm_rev} (expected: deployed, revision >= 2)"
else
  fail "Helm release '${NS_HELM}/${RELEASE}' has STATUS='${helm_status:-missing}' and REVISION='${helm_rev:-missing}' (expected: deployed, revision >= 2)"
fi

# 5. The Helm-managed Deployment has replicas=2 (and readyReplicas=2) as set by the last helm upgrade
helm_dep_ready=""
for _ in $(seq 1 15); do
  helm_dep_ready="$(kubectl -n "$NS_HELM" get deployment "$RELEASE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "${helm_dep_ready:-0}" -eq 2 ]] && break
  sleep 2
done
helm_dep_rep="$(kubectl -n "$NS_HELM" get deployment "$RELEASE" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
if [[ "${helm_dep_rep:-0}" -eq 2 && "${helm_dep_ready:-0}" -eq 2 ]]; then
  pass "Helm-managed Deployment '${NS_HELM}/${RELEASE}' has spec.replicas=${helm_dep_rep} and readyReplicas=${helm_dep_ready} (expected: 2)"
else
  fail "Helm-managed Deployment '${NS_HELM}/${RELEASE}' has spec.replicas=${helm_dep_rep:-missing} and readyReplicas=${helm_dep_ready:-0} (expected: 2)"
fi

# 6. /root/lab17/report.txt has both keys with non-empty values and kustomize_prod_replicas matches live object
if [[ -f "$REPORT_FILE" ]]; then
  rep_prod="$(awk -F'=' '/^kustomize_prod_replicas=/ {print $2; exit}' "$REPORT_FILE" | tr -d '[:space:]')"
  rep_helm="$(awk -F'=' '/^helm_revision=/ {print $2; exit}' "$REPORT_FILE" | tr -d '[:space:]')"
  if [[ -n "$rep_prod" && -n "$rep_helm" && "$rep_prod" == "${prod_spec_rep:-3}" && "${prod_spec_rep:-0}" -eq 3 ]]; then
    pass "Report '${REPORT_FILE}' contains kustomize_prod_replicas=${rep_prod} (matches live prod-web=${prod_spec_rep}) and helm_revision=${rep_helm}"
  else
    fail "Report '${REPORT_FILE}' has kustomize_prod_replicas='${rep_prod:-missing}' (live='${prod_spec_rep:-missing}') and helm_revision='${rep_helm:-missing}' (expected: both non-empty and matching live prod replicas=3)"
  fi
else
  fail "Report file '${REPORT_FILE}' does not exist (expected: kustomize_prod_replicas=<n> and helm_revision=<n>)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
