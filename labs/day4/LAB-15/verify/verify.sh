#!/usr/bin/env bash
# LAB-15 verifier: integrated incident (Service selector + Ingress backend), end-to-end HTTP proof.
# Deliberately not 'set -e': a failing assertion prints instead of aborting.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG tidak diset; memakai %s\n' "$KUBECONFIG"
fi

NS="gisp-app"
PORT=30081
passed=0
total=0

pass() { passed=$((passed + 1)); total=$((total + 1)); printf 'PASS: %s\n' "$*"; }
fail() { total=$((total + 1)); printf 'FAIL: %s\n' "$*"; }

# 1. Deployment portal: 2/2 Ready, nginx:1.27-alpine
printf 'INFO: menunggu Deployment %s/portal 2/2 Ready (maks 60s)...\n' "$NS"
ready=0
for _ in $(seq 1 20); do
  ready="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "${ready:-0}" -eq 2 ]] && break
  sleep 3
done
dep_img="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
if [[ "${ready:-0}" -eq 2 && ( "$dep_img" == "nginx:1.27-alpine" || "$dep_img" == "docker.io/library/nginx:1.27-alpine" ) ]]; then
  pass "Deployment '${NS}/portal' has 2/2 Ready with image '${dep_img}' (expected: 2/2 Ready, nginx:1.27-alpine)"
else
  fail "Deployment '${NS}/portal' has ${ready:-0}/2 Ready with image '${dep_img:-missing}' (expected: 2/2 Ready, nginx:1.27-alpine)"
fi

# 2. Service portal: selector matches the pods, 2 ready endpoints
sel="$(kubectl -n "$NS" get svc portal -o jsonpath='{.spec.selector.app}' 2>/dev/null || true)"
ep=""
for _ in $(seq 1 10); do
  ep="$(kubectl -n "$NS" get endpoints portal -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
  [[ -n "$ep" ]] && break
  sleep 2
done
ep_count="$(printf '%s\n' "$ep" | awk '{print NF}')"
if [[ "$sel" == "portal-app" && "${ep_count:-0}" -eq 2 ]]; then
  pass "Service '${NS}/portal' selector app='${sel}' with ${ep_count} ready endpoints (expected: app=portal-app, 2 endpoints)"
else
  fail "Service '${NS}/portal' selector app='${sel:-missing}' with ${ep_count:-0} endpoints (expected: app=portal-app, 2 endpoints)"
fi

# 3. Ingress portal-ingress: host portal.lab.local -> Service portal port 80
ing_host="$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
ing_svc="$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || true)"
ing_port="$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || true)"
ing_port_name="$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.name}' 2>/dev/null || true)"
if [[ "$ing_host" == "portal.lab.local" && "$ing_svc" == "portal" && ( "$ing_port" == "80" || -n "$ing_port_name" ) ]]; then
  pass "Ingress '${NS}/portal-ingress' routes '${ing_host}' to '${ing_svc}:${ing_port:-$ing_port_name}' (expected: portal.lab.local -> portal:80)"
else
  fail "Ingress '${NS}/portal-ingress' routes host='${ing_host:-missing}' to '${ing_svc:-missing}:${ing_port:-${ing_port_name:-missing}}' (expected: portal.lab.local -> portal:80)"
fi

# 4. ConfigMap app-config still present and consumed by the Deployment
cm_val="$(kubectl -n "$NS" get configmap app-config -o jsonpath='{.data.GREETING}' 2>/dev/null || true)"
cm_ref="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].configMapRef.name}' 2>/dev/null || true)"
if [[ "$cm_val" == "halo-lab15" ]] && printf '%s' "$cm_ref" | grep -qw "app-config"; then
  pass "ConfigMap '${NS}/app-config' GREETING='${cm_val}' is consumed via envFrom (expected: 'halo-lab15', envFrom app-config)"
else
  fail "ConfigMap '${NS}/app-config' GREETING='${cm_val:-missing}', envFrom='${cm_ref:-none}' (expected: 'halo-lab15', envFrom app-config)"
fi

# 5. HTTP probe: Host portal.lab.local pada NodePort 30081 -> 200 + body nginx
root_code=""
for _ in $(seq 1 15); do
  root_code="$(curl -s -o /tmp/lab15-root.out -w '%{http_code}' --max-time 5 -H 'Host: portal.lab.local' "http://localhost:${PORT}/" 2>/dev/null || true)"
  [[ "$root_code" == "200" ]] && break
  sleep 2
done
body_ok=0
grep -qi "nginx" /tmp/lab15-root.out 2>/dev/null && body_ok=1
if [[ "$root_code" == "200" && "$body_ok" -eq 1 ]]; then
  pass "HTTP probe 'curl -H \"Host: portal.lab.local\" http://localhost:${PORT}/' returned 200 with nginx body (expected: 200)"
else
  fail "HTTP probe 'curl -H \"Host: portal.lab.local\" http://localhost:${PORT}/' returned ${root_code:-000} (expected: 200 with nginx body)"
fi
rm -f /tmp/lab15-root.out

# 6. HTTP probe of the PVC file: /data/proof.txt berisi token lab15-proof
proof_code=""
proof_body=""
for _ in $(seq 1 15); do
  proof_code="$(curl -s -o /tmp/lab15-proof.out -w '%{http_code}' --max-time 5 -H 'Host: portal.lab.local' "http://localhost:${PORT}/data/proof.txt" 2>/dev/null || true)"
  proof_body="$(tr -d '\r\n' < /tmp/lab15-proof.out 2>/dev/null || true)"
  [[ "$proof_code" == "200" && -n "$proof_body" ]] && break
  sleep 2
done
rm -f /tmp/lab15-proof.out
if [[ "$proof_code" == "200" && "$proof_body" == "lab15-proof" ]]; then
  pass "PVC file served over HTTP: '/data/proof.txt' = '${proof_body}' (expected: lab15-proof)"
else
  fail "PVC file served over HTTP: '/data/proof.txt' returned ${proof_code:-000} with '${proof_body:-empty}' (expected: 200, lab15-proof)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
fi
printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
exit 1
