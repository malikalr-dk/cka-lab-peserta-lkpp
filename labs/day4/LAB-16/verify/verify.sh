#!/usr/bin/env bash
# LAB-16 verifier: final recovery + evidence report (assessment).
# Deliberately not 'set -e': a failing assertion prints instead of aborting.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG tidak diset; memakai %s\n' "$KUBECONFIG"
fi

NS="cka-lab16"
PORT=30081
REPORT="/root/lab/lab16-report.txt"
passed=0
total=0

pass() { passed=$((passed + 1)); total=$((total + 1)); printf 'PASS: %s\n' "$*"; }
fail() { total=$((total + 1)); printf 'FAIL: %s\n' "$*"; }

# 1. Deployment portal scaled back to 2 and fully Ready
printf 'INFO: menunggu Deployment %s/portal 2/2 Ready (maks 60s)...\n' "$NS"
ready=0
for _ in $(seq 1 20); do
  ready="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "${ready:-0}" -eq 2 ]] && break
  sleep 3
done
spec_rep="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
if [[ "${spec_rep:-0}" == "2" && "${ready:-0}" -eq 2 ]]; then
  pass "Deployment '${NS}/portal' has ${ready}/2 Ready replicas (expected: spec.replicas=2, 2 Ready)"
else
  fail "Deployment '${NS}/portal' has spec.replicas=${spec_rep:-missing}, ready=${ready:-0} (expected: 2 and 2 Ready)"
fi

# 2. Service portal has 2 ready endpoints
ep=""
for _ in $(seq 1 10); do
  ep="$(kubectl -n "$NS" get endpoints portal -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
  [[ -n "$ep" ]] && break
  sleep 2
done
ep_count="$(printf '%s\n' "$ep" | awk '{print NF}')"
if [[ "${ep_count:-0}" -eq 2 ]]; then
  pass "Service '${NS}/portal' has ${ep_count} ready endpoints (expected: 2)"
else
  fail "Service '${NS}/portal' has ${ep_count:-0} endpoints (expected: 2)"
fi

# 3. Ingress backend port fixed to 80 on Service portal
ing_svc="$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || true)"
ing_port="$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || true)"
if [[ "$ing_svc" == "portal" && "$ing_port" == "80" ]]; then
  pass "Ingress '${NS}/portal-ingress' backend is '${ing_svc}:${ing_port}' (expected: portal:80)"
else
  fail "Ingress '${NS}/portal-ingress' backend is '${ing_svc:-missing}:${ing_port:-missing}' (expected: portal:80)"
fi

# 4. HTTP probe returns 200 with nginx body
root_code=""
for _ in $(seq 1 15); do
  root_code="$(curl -s -o /tmp/lab16-root.out -w '%{http_code}' --max-time 5 -H 'Host: portal.lab.local' "http://localhost:${PORT}/" 2>/dev/null || true)"
  [[ "$root_code" == "200" ]] && break
  sleep 2
done
body_ok=0
grep -qi "nginx" /tmp/lab16-root.out 2>/dev/null && body_ok=1
if [[ "$root_code" == "200" && "$body_ok" -eq 1 ]]; then
  pass "HTTP probe 'Host: portal.lab.local' on :${PORT} returned 200 with nginx body (expected: 200)"
else
  fail "HTTP probe 'Host: portal.lab.local' on :${PORT} returned ${root_code:-000} (expected: 200 with nginx body)"
fi
rm -f /tmp/lab16-root.out

# 5. PVC file served over HTTP
proof_code=""
proof_body=""
for _ in $(seq 1 15); do
  proof_code="$(curl -s -o /tmp/lab16-proof.out -w '%{http_code}' --max-time 5 -H 'Host: portal.lab.local' "http://localhost:${PORT}/data/proof.txt" 2>/dev/null || true)"
  proof_body="$(tr -d '\r\n' < /tmp/lab16-proof.out 2>/dev/null || true)"
  [[ "$proof_code" == "200" && -n "$proof_body" ]] && break
  sleep 2
done
rm -f /tmp/lab16-proof.out
if [[ "$proof_code" == "200" && "$proof_body" == "lab16-proof" ]]; then
  pass "PVC file served over HTTP: '/data/proof.txt' = '${proof_body}' (expected: lab16-proof)"
else
  fail "PVC file served over HTTP: '/data/proof.txt' returned ${proof_code:-000} with '${proof_body:-empty}' (expected: 200, lab16-proof)"
fi

# 6. Incident report file with four non-empty keys
incident=""; root_cause=""; action=""; proof=""
if [[ -f "$REPORT" ]]; then
  incident="$(awk -F= '/^incident=/{sub(/^incident=/,""); print; exit}' "$REPORT" | tr -d '\r')"
  root_cause="$(awk -F= '/^root_cause=/{sub(/^root_cause=/,""); print; exit}' "$REPORT" | tr -d '\r')"
  action="$(awk -F= '/^action=/{sub(/^action=/,""); print; exit}' "$REPORT" | tr -d '\r')"
  proof="$(awk -F= '/^proof=/{sub(/^proof=/,""); print; exit}' "$REPORT" | tr -d '\r')"
fi
if [[ -n "$incident" && -n "$root_cause" && -n "$action" && "$proof" == "200" ]]; then
  pass "Report '${REPORT}' has incident, root_cause, action and proof=200 (expected: four keys, proof=200)"
else
  fail "Report '${REPORT}' has incident='${incident:-missing}', root_cause='${root_cause:-missing}', action='${action:-missing}', proof='${proof:-missing}' (expected: four keys, proof=200)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
fi
printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
exit 1
