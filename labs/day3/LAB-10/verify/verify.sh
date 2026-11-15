#!/usr/bin/env bash
# LAB-10 verifier: Traefik Ingress creation and broken-ingress network troubleshooting
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="gisp-app"
TRAEFIK_NS="traefik"

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

# Wait briefly for Traefik controller pods to be Running
printf 'INFO: waiting up to 30s for Traefik pod(s) in namespace %s to be Running...\n' "$TRAEFIK_NS"
for _ in $(seq 1 10); do
  t_run="$(kubectl -n "$TRAEFIK_NS" get pods --no-headers 2>/dev/null | awk '$3 == "Running" {c++} END {print c+0}')"
  [[ "${t_run:-0}" -ge 1 ]] && break
  sleep 3
done

# 1. Traefik pod(s) Running in namespace traefik
traefik_running="$(kubectl -n "$TRAEFIK_NS" get pods --no-headers 2>/dev/null | awk '$3 == "Running" {c++} END {print c+0}')"
if [[ "${traefik_running:-0}" -ge 1 ]]; then
  pass "Traefik controller in namespace '${TRAEFIK_NS}' has ${traefik_running} Running pod(s) (expected: >=1)"
else
  fail "Traefik controller in namespace '${TRAEFIK_NS}' has ${traefik_running:-0} Running pod(s) (expected: >=1)"
fi

# 2. Deployment 'app' and Service 'app' exist and are ready in gisp-app
app_ready="$(kubectl -n "$NS" get deployment app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
svc_port="$(kubectl -n "$NS" get svc app -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)"
if [[ "${app_ready:-0}" -eq 2 && "$svc_port" == "80" ]]; then
  pass "Deployment '${NS}/app' (readyReplicas=${app_ready}) and Service '${NS}/app' (port=${svc_port}) are ready (expected: 2 replicas, port 80)"
else
  fail "Deployment '${NS}/app' (readyReplicas=${app_ready:-0}) or Service '${NS}/app' (port=${svc_port:-missing}) not ready (expected: 2 replicas, port 80)"
fi

# Helper: validate that an Ingress exists, matches expected host, and points to an existing Service and port in $NS
check_ingress_backend() {
  local ing_name="$1"
  local exp_host="$2"
  local host svc_name svc_port_num svc_port_name target_svc_ports

  host="$(kubectl -n "$NS" get ingress "$ing_name" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
  svc_name="$(kubectl -n "$NS" get ingress "$ing_name" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || true)"
  svc_port_num="$(kubectl -n "$NS" get ingress "$ing_name" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || true)"
  svc_port_name="$(kubectl -n "$NS" get ingress "$ing_name" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.name}' 2>/dev/null || true)"

  if [[ "$host" != "$exp_host" || -z "$svc_name" ]]; then
    fail "Ingress '${NS}/${ing_name}' has host='${host:-missing}', backend.service.name='${svc_name:-missing}' (expected: host '${exp_host}' and valid Service in '${NS}')"
    return
  fi

  if ! kubectl -n "$NS" get svc "$svc_name" >/dev/null 2>&1; then
    fail "Ingress '${NS}/${ing_name}' points to non-existent Service '${NS}/${svc_name}' (expected: existing Service 'app')"
    return
  fi

  target_svc_ports="$(kubectl -n "$NS" get svc "$svc_name" -o jsonpath='{.spec.ports[*].port} {.spec.ports[*].name}' 2>/dev/null || true)"
  local port_val="${svc_port_num:-$svc_port_name}"
  if [[ -n "$port_val" ]] && printf ' %s ' "$target_svc_ports" | grep -q " ${port_val} "; then
    pass "Ingress '${NS}/${ing_name}' (host='${host}') points to existing Service '${NS}/${svc_name}' on valid port '${port_val}' (expected: Service 'app' port 80)"
  else
    fail "Ingress '${NS}/${ing_name}' backend port '${port_val:-missing}' does not match Service '${NS}/${svc_name}' ports (${target_svc_ports:-none})"
  fi
}

# 3. Ingress 'app-ingress' exists and points to valid Service & port
check_ingress_backend "app-ingress" "app.lab.local"

# 4. Ingress 'broken-ingress' exists and points to valid Service & port
check_ingress_backend "broken-ingress" "broken.lab.local"

# 5. HTTP probe for Host: app.lab.local on localhost:30081 returns 200 and nginx body
app_code=""
app_body=""
for _ in $(seq 1 5); do
  app_code="$(curl -s -o /tmp/lab10-app.out -w '%{http_code}' --max-time 5 -H 'Host: app.lab.local' http://localhost:30081/ 2>/dev/null || true)"
  app_body="$(cat /tmp/lab10-app.out 2>/dev/null || true)"
  [[ "$app_code" == "200" ]] && break
  sleep 2
done
rm -f /tmp/lab10-app.out

if [[ "$app_code" == "200" ]] && printf '%s\n' "$app_body" | grep -qi "Welcome to nginx"; then
  pass "HTTP probe 'curl -H \"Host: app.lab.local\" http://localhost:30081/' returned HTTP ${app_code} with nginx welcome page (expected: 200 + nginx)"
else
  fail "HTTP probe 'curl -H \"Host: app.lab.local\" http://localhost:30081/' returned HTTP ${app_code:-000} (expected: 200 + 'Welcome to nginx')"
fi

# 6. HTTP probe for Host: broken.lab.local on localhost:30081 returns 200 and nginx body
broken_code=""
broken_body=""
for _ in $(seq 1 5); do
  broken_code="$(curl -s -o /tmp/lab10-broken.out -w '%{http_code}' --max-time 5 -H 'Host: broken.lab.local' http://localhost:30081/ 2>/dev/null || true)"
  broken_body="$(cat /tmp/lab10-broken.out 2>/dev/null || true)"
  [[ "$broken_code" == "200" ]] && break
  sleep 2
done
rm -f /tmp/lab10-broken.out

if [[ "$broken_code" == "200" ]] && printf '%s\n' "$broken_body" | grep -qi "Welcome to nginx"; then
  pass "HTTP probe 'curl -H \"Host: broken.lab.local\" http://localhost:30081/' returned HTTP ${broken_code} with nginx welcome page (expected: 200 + nginx)"
else
  fail "HTTP probe 'curl -H \"Host: broken.lab.local\" http://localhost:30081/' returned HTTP ${broken_code:-000} (expected: 200 + 'Welcome to nginx')"
fi

# 7. Endpoints for Service 'app' has 2 ready backend addresses
ep_ips="$(kubectl -n "$NS" get endpoints app -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
ep_count="$(printf '%s\n' "$ep_ips" | awk '{print NF}')"
if [[ "${ep_count:-0}" -eq 2 ]]; then
  pass "Endpoints '${NS}/app' has ${ep_count} ready backend addresses (${ep_ips}) (expected: 2)"
else
  fail "Endpoints '${NS}/app' has ${ep_count:-0} ready backend addresses (expected: 2)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
