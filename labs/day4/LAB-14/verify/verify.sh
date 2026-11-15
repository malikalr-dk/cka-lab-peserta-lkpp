#!/usr/bin/env bash
# LAB-14 verifier: Helm release lifecycle (install -> upgrade -> rollback -> upgrade) plus
# a live Prometheus/Grafana stack installed from the local chart.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG tidak diset; memakai %s\n' "$KUBECONFIG"
fi

NS_HELM="gisp-app"
NS_MON="lab-monitoring"
RELEASE="lab17-web"
MON_RELEASE="kube-prometheus"
REPORT="/root/lab17/report.txt"
passed=0
total=0

pass() { passed=$((passed + 1)); total=$((total + 1)); printf 'PASS: %s\n' "$*"; }
fail() { total=$((total + 1)); printf 'FAIL: %s\n' "$*"; }

# 1. Rilis Helm deployed, REVISION >= 2
helm_status_out="$(helm -n "$NS_HELM" status "$RELEASE" 2>/dev/null || true)"
helm_status="$(printf '%s\n' "$helm_status_out" | awk -F': ' '/^STATUS:/ {print $2; exit}' | tr -d '[:space:]')"
helm_rev="$(printf '%s\n' "$helm_status_out" | awk -F': ' '/^REVISION:/ {print $2; exit}' | tr -d '[:space:]')"
if [[ "$helm_status" == "deployed" && "${helm_rev:-0}" =~ ^[0-9]+$ && "${helm_rev:-0}" -ge 2 ]]; then
  pass "Helm release '${NS_HELM}/${RELEASE}' STATUS=${helm_status}, REVISION=${helm_rev} (expected: deployed, revision >= 2)"
else
  fail "Helm release '${NS_HELM}/${RELEASE}' STATUS='${helm_status:-missing}', REVISION='${helm_rev:-missing}' (expected: deployed, revision >= 2)"
fi

# 2. Deployment hasil Helm: 2 replika Ready
#    Retry hanya berguna kalau objeknya ada; Deployment yang belum dibuat tidak akan muncul
#    dalam 30 detik, jadi jangan bakar kuota retry (state awal lab memang belum punya rilis).
helm_dep_ready=""
if kubectl -n "$NS_HELM" get deployment "$RELEASE" >/dev/null 2>&1; then
  for _ in $(seq 1 15); do
    helm_dep_ready="$(kubectl -n "$NS_HELM" get deployment "$RELEASE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
    [[ "${helm_dep_ready:-0}" -eq 2 ]] && break
    sleep 2
  done
fi
helm_dep_rep="$(kubectl -n "$NS_HELM" get deployment "$RELEASE" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
if [[ "${helm_dep_rep:-0}" == "2" && "${helm_dep_ready:-0}" -eq 2 ]]; then
  pass "Helm-managed Deployment '${NS_HELM}/${RELEASE}' has replicas=${helm_dep_ready}/${helm_dep_rep} (expected: 2/2 Ready)"
else
  fail "Helm-managed Deployment '${NS_HELM}/${RELEASE}' has replicas=${helm_dep_ready:-0}/${helm_dep_rep:-0} (expected: 2/2 Ready)"
fi

# 3. Rilis monitoring terpasang
mon_status="$(helm -n "$NS_MON" status "$MON_RELEASE" 2>/dev/null | awk -F': ' '/^STATUS:/ {print $2; exit}' | tr -d '[:space:]')"
if [[ "$mon_status" == "deployed" ]]; then
  pass "Monitoring release '${NS_MON}/${MON_RELEASE}' STATUS=${mon_status} (expected: deployed)"
else
  fail "Monitoring release '${NS_MON}/${MON_RELEASE}' STATUS='${mon_status:-missing}' (expected: deployed)"
fi

# 4. Prometheus siap
#    Nama StatefulSet dicari lewat label: chart memotong nama default menjadi
#    `prometheus-kube-prometheus-kube-prome-prometheus`, jadi nama hardcode tidak pernah cocok.
prom_sts="$(kubectl -n "$NS_MON" get statefulset -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
[[ -n "$prom_sts" ]] || prom_sts="prometheus-${MON_RELEASE}-prometheus"
prom_ready=""
if kubectl -n "$NS_MON" get statefulset "$prom_sts" >/dev/null 2>&1; then
  for _ in $(seq 1 20); do
    prom_ready="$(kubectl -n "$NS_MON" get statefulset "$prom_sts" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
    [[ "${prom_ready:-0}" -ge 1 ]] && break
    sleep 6
  done
fi
if [[ "${prom_ready:-0}" -ge 1 ]]; then
  pass "Prometheus '${NS_MON}/${prom_sts}' has ${prom_ready} ready replica (expected: >= 1)"
else
  fail "Prometheus '${NS_MON}/${prom_sts}' has ${prom_ready:-0} ready replicas (expected: >= 1)"
fi

# 5. Grafana siap
graf_ready=""
if kubectl -n "$NS_MON" get deployment "${MON_RELEASE}-grafana" >/dev/null 2>&1; then
  for _ in $(seq 1 20); do
    graf_ready="$(kubectl -n "$NS_MON" get deployment "${MON_RELEASE}-grafana" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
    [[ "${graf_ready:-0}" -ge 1 ]] && break
    sleep 6
  done
fi
if [[ "${graf_ready:-0}" -ge 1 ]]; then
  pass "Grafana '${NS_MON}/${MON_RELEASE}-grafana' has ${graf_ready} ready replica (expected: >= 1)"
else
  fail "Grafana '${NS_MON}/${MON_RELEASE}-grafana' has ${graf_ready:-0} ready replicas (expected: >= 1)"
fi

# 6. Laporan: helm_revision cocok rilis hidup, prometheus_ready=yes
rep_rev=""
rep_mon=""
if [[ -f "$REPORT" ]]; then
  rep_rev="$(awk -F'=' '/^helm_revision=/ {print $2; exit}' "$REPORT" | tr -d '[:space:]')"
  rep_mon="$(awk -F'=' '/^prometheus_ready=/ {print $2; exit}' "$REPORT" | tr -d '[:space:]')"
fi
if [[ -n "$helm_rev" && "$rep_rev" == "$helm_rev" && "$rep_mon" == "yes" ]]; then
  pass "Report '${REPORT}' has helm_revision=${rep_rev} (matches live) and prometheus_ready=${rep_mon} (expected: ${helm_rev}, yes)"
else
  fail "Report '${REPORT}' has helm_revision='${rep_rev:-missing}' (live=${helm_rev:-0}), prometheus_ready='${rep_mon:-missing}' (expected: ${helm_rev:-?}, yes)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
fi
printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
exit 1
