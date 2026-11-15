#!/usr/bin/env bash
# LAB-17 verifier: Gateway API (GatewayClass, Gateway, HTTPRoute creation & broken-route port fix)
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="cka-lab15"
TRAEFIK_NS="traefik"

# Polls are only useful while the object exists. In starter state nothing is there to wait for,
# and 7 x 30s of retries turns a clear FAIL into a two-minute silence.
ptries() { kubectl "$@" >/dev/null 2>&1 && echo 15 || echo 1; }

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

# 1. Gateway API CRDs (gatewayclasses, gateways, httproutes) are present and Established
crd_ok=0
for _ in $(seq 1 15); do
  gc_est="$(kubectl get crd gatewayclasses.gateway.networking.k8s.io -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  gw_est="$(kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  hr_est="$(kubectl get crd httproutes.gateway.networking.k8s.io -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  if [[ "$gc_est" == *"Established=True"* && "$gw_est" == *"Established=True"* && "$hr_est" == *"Established=True"* ]]; then
    crd_ok=1
    break
  fi
  sleep 2
done
if [[ "$crd_ok" -eq 1 ]]; then
  pass "Gateway API CRDs (gatewayclasses, gateways, httproutes) are present and Established=True (expected: Established=True)"
else
  fail "Gateway API CRDs missing or not Established (expected: gatewayclasses, gateways, httproutes Established=True)"
fi

# 2. GatewayClass 'traefik' exists and is Accepted=True (poll up to 30s)
gwc_acc=""
for _ in $(seq 1 15); do
  gwc_acc="$(kubectl get gatewayclass traefik -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  [[ "$gwc_acc" == *"Accepted=True"* ]] && break
  sleep 2
done
if [[ "$gwc_acc" == *"Accepted=True"* ]]; then
  pass "GatewayClass 'traefik' has status condition Accepted=True (expected: Accepted=True)"
else
  fail "GatewayClass 'traefik' has status conditions '${gwc_acc:-missing}' (expected: Accepted=True)"
fi

# 3. Gateway 'web-gateway' exists in cka-lab15 with gatewayClassName=traefik, HTTP port 80, and Accepted=True (poll)
gw_class=""
gw_port=""
gw_proto=""
gw_cond=""
for _ in $(seq 1 "$(ptries -n "$NS" get gateway web-gateway)"); do
  gw_class="$(kubectl -n "$NS" get gateway web-gateway -o jsonpath='{.spec.gatewayClassName}' 2>/dev/null || true)"
  gw_port="$(kubectl -n "$NS" get gateway web-gateway -o jsonpath='{.spec.listeners[0].port}' 2>/dev/null || true)"
  gw_proto="$(kubectl -n "$NS" get gateway web-gateway -o jsonpath='{.spec.listeners[0].protocol}' 2>/dev/null || true)"
  gw_cond="$(kubectl -n "$NS" get gateway web-gateway -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  [[ "$gw_class" == "traefik" && "$gw_port" == "80" && "$gw_cond" == *"Accepted=True"* ]] && break
  sleep 2
done
if [[ "$gw_class" == "traefik" && "$gw_port" == "80" && "$gw_proto" == "HTTP" && "$gw_cond" == *"Accepted=True"* ]]; then
  pass "Gateway '${NS}/web-gateway' (class=${gw_class}, listener=${gw_proto}:${gw_port}) has Accepted=True (expected: traefik, HTTP:80, Accepted=True)"
else
  fail "Gateway '${NS}/web-gateway' has class='${gw_class:-missing}', listener='${gw_proto:-?}:${gw_port:-?}', conditions='${gw_cond:-missing}' (expected: traefik, HTTP:80, Accepted=True)"
fi

# 4. Gateway 'web-gateway' has status.addresses populated or Programmed=True (poll up to 30s)
gw_addr=""
gw_prog=""
for _ in $(seq 1 "$(ptries -n "$NS" get gateway web-gateway)"); do
  gw_addr="$(kubectl -n "$NS" get gateway web-gateway -o jsonpath='{.status.addresses[*].value}' 2>/dev/null || true)"
  # Re-read the conditions here: assertion 3 stops as soon as Accepted=True, which can land before
  # the controller sets Programmed, so reusing the older snapshot would time out and false-FAIL.
  gw_prog="$(kubectl -n "$NS" get gateway web-gateway -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  [[ -n "$gw_addr" || "$gw_prog" == *"Programmed=True"* ]] && break
  sleep 2
done
if [[ -n "$gw_addr" ]]; then
  pass "Gateway '${NS}/web-gateway' has status.addresses='${gw_addr}' (expected: populated address)"
elif [[ "$gw_prog" == *"Programmed=True"* ]]; then
  pass "Gateway '${NS}/web-gateway' has no published address but Programmed=True (expected: populated address / Programmed=True)"
else
  fail "Gateway '${NS}/web-gateway' has empty status.addresses and conditions='${gw_prog:-missing}' (expected: populated address / Programmed=True)"
fi

# 5. HTTPRoute 'web-route' attaches to web-gateway for host web.gw.local and has Accepted=True & ResolvedRefs=True
wr_cond=""
wr_host=""
for _ in $(seq 1 "$(ptries -n "$NS" get httproute web-route)"); do
  wr_host="$(kubectl -n "$NS" get httproute web-route -o jsonpath='{.spec.hostnames[0]}' 2>/dev/null || true)"
  wr_cond="$(kubectl -n "$NS" get httproute web-route -o jsonpath='{range .status.parents[*].conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  [[ "$wr_cond" == *"Accepted=True"* && "$wr_cond" == *"ResolvedRefs=True"* ]] && break
  sleep 2
done
if [[ "$wr_host" == "web.gw.local" && "$wr_cond" == *"Accepted=True"* && "$wr_cond" == *"ResolvedRefs=True"* ]]; then
  pass "HTTPRoute '${NS}/web-route' (host=${wr_host}) has parent conditions Accepted=True and ResolvedRefs=True (expected: web.gw.local, Accepted=True, ResolvedRefs=True)"
else
  fail "HTTPRoute '${NS}/web-route' has host='${wr_host:-missing}', conditions='${wr_cond:-missing}' (expected: web.gw.local, Accepted=True, ResolvedRefs=True)"
fi

# 6. Starter broken HTTPRoute 'broken-route' has been fixed (backendRefs[0].port == 80)
br_svc="$(kubectl -n "$NS" get httproute broken-route -o jsonpath='{.spec.rules[0].backendRefs[0].name}' 2>/dev/null || true)"
br_port="$(kubectl -n "$NS" get httproute broken-route -o jsonpath='{.spec.rules[0].backendRefs[0].port}' 2>/dev/null || true)"
if [[ "$br_svc" == "web" && "$br_port" == "80" ]]; then
  pass "HTTPRoute '${NS}/broken-route' backendRefs fixed to service='${br_svc}', port=${br_port} (expected: web, port 80)"
else
  fail "HTTPRoute '${NS}/broken-route' has backendRefs service='${br_svc:-missing}', port=${br_port:-missing} (expected: web, port 80)"
fi

# 7. HTTPRoute 'broken-route' has Accepted=True and ResolvedRefs=True
br_cond=""
# ResolvedRefs stays False while backendRefs points at a port the Service does not expose, so a
# still-broken route has nothing to wait for; poll only once the port looks fixed.
br_tries=15
[[ "$br_port" == "80" ]] || br_tries=1
for _ in $(seq 1 "$br_tries"); do
  br_cond="$(kubectl -n "$NS" get httproute broken-route -o jsonpath='{range .status.parents[*].conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  [[ "$br_cond" == *"Accepted=True"* && "$br_cond" == *"ResolvedRefs=True"* ]] && break
  sleep 2
done
if [[ "$br_cond" == *"Accepted=True"* && "$br_cond" == *"ResolvedRefs=True"* ]]; then
  pass "HTTPRoute '${NS}/broken-route' has parent conditions Accepted=True and ResolvedRefs=True (expected: Accepted=True, ResolvedRefs=True)"
else
  fail "HTTPRoute '${NS}/broken-route' has conditions='${br_cond:-missing}' (expected: Accepted=True, ResolvedRefs=True)"
fi

# Discover Traefik HTTP NodePort (defaults to 30081 from setup.sh)
np="$(kubectl -n "$TRAEFIK_NS" get svc traefik -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}' 2>/dev/null || true)"
[[ -z "$np" ]] && np="$(kubectl -n "$TRAEFIK_NS" get svc traefik -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"
np="${np:-30081}"

# A route that does not exist cannot start answering, so a starter-state run must not burn
# ~2 minutes of retries before the same FAIL. One gate per hostname: a participant who fixes broken-route first would otherwise get a
# single-shot probe for it while Traefik is still programming the route (false FAIL).
web_tries=15
kubectl -n "$NS" get httproute web-route >/dev/null 2>&1 || web_tries=1
broken_tries=15
kubectl -n "$NS" get httproute broken-route >/dev/null 2>&1 || broken_tries=1
# A route still pointing at a port the Service does not expose cannot answer, so it is not worth
# 30s of retries either.
[[ "$br_port" == "80" ]] || broken_tries=1

# 8. HTTP request through Traefik Gateway for Host: web.gw.local returns nginx welcome page
web_body=""
for _ in $(seq 1 "$web_tries"); do
  web_body="$(curl -s --max-time 3 -H 'Host: web.gw.local' "http://localhost:${np}/" 2>/dev/null || true)"
  if printf '%s\n' "$web_body" | grep -qi "Welcome to nginx"; then
    break
  fi
  sleep 2
done
if printf '%s\n' "$web_body" | grep -qi "Welcome to nginx"; then
  pass "HTTP probe 'curl -H \"Host: web.gw.local\" http://localhost:${np}/' returned nginx welcome page (expected: 'Welcome to nginx')"
else
  fail "HTTP probe 'curl -H \"Host: web.gw.local\" http://localhost:${np}/' did not return nginx welcome page (expected: 'Welcome to nginx')"
fi

# 9. HTTP request through Traefik Gateway for Host: broken.gw.local returns nginx welcome page
broken_body=""
for _ in $(seq 1 "$broken_tries"); do
  broken_body="$(curl -s --max-time 3 -H 'Host: broken.gw.local' "http://localhost:${np}/" 2>/dev/null || true)"
  if printf '%s\n' "$broken_body" | grep -qi "Welcome to nginx"; then
    break
  fi
  sleep 2
done
if printf '%s\n' "$broken_body" | grep -qi "Welcome to nginx"; then
  pass "HTTP probe 'curl -H \"Host: broken.gw.local\" http://localhost:${np}/' returned nginx welcome page (expected: 'Welcome to nginx')"
else
  fail "HTTP probe 'curl -H \"Host: broken.gw.local\" http://localhost:${np}/' did not return nginx welcome page (expected: 'Welcome to nginx')"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
