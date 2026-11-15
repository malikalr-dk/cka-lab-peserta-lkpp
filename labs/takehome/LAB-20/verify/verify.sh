#!/usr/bin/env bash
# LAB-20 verifier:
# Part A: CRD configforges.lab.example.com, kubectl explain, OpenAPI validation (invalid rejected, valid accepted)
# Part B: Traefik CRD operator (ingressroutes.traefik.io, IngressRoute app-route -> web for app.lab20.local,
#         HTTP 200 nginx response via NodePort 30082, and 404 after deleting IngressRoute), plus reset.sh check.
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="cka-lab20"
TRAEFIK_NS="traefik"
CRD_NAME="configforges.lab.example.com"
TRAEFIK_CRD="ingressroutes.traefik.io"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
RESET_SCRIPT="${SCRIPT_DIR}/../reset/reset.sh"
# `bash -s < verify.sh` (the documented remote runner) makes BASH_SOURCE /dev/stdin, so
# SCRIPT_DIR resolves to /dev and the reset.sh sanity check below failed for the wrong reason.
if [[ ! -f "$RESET_SCRIPT" ]]; then
  RESET_SCRIPT="/opt/lab/labs/LAB-20/reset/reset.sh"
fi
IR_BACKUP="$(mktemp /tmp/lab20-ir-backup.XXXXXX.yaml 2>/dev/null || echo /tmp/lab20-ir-backup.yaml)"

# Polls are only useful while the object exists. In starter state nothing is there to wait for,
# and multiple 30s retry loops would turn a clear FAIL into a multi-minute silence.
ptries() { kubectl "$@" >/dev/null 2>&1 && echo 15 || echo 1; }

cleanup() {
  kubectl -n "$NS" delete configforge invalid-probe --ignore-not-found >/dev/null 2>&1 || true
  if [[ -s "$IR_BACKUP" ]]; then
    kubectl apply -f "$IR_BACKUP" >/dev/null 2>&1 || true
  fi
  rm -f "$IR_BACKUP" >/dev/null 2>&1 || true
}
trap cleanup EXIT

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

# 1. CRD 'configforges.lab.example.com' Established=True, scope Namespaced, shortName cfgforge
crd_cond=""
crd_scope=""
crd_short=""
for _ in $(seq 1 "$(ptries get crd "$CRD_NAME")"); do
  crd_cond="$(kubectl get crd "$CRD_NAME" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  crd_scope="$(kubectl get crd "$CRD_NAME" -o jsonpath='{.spec.scope}' 2>/dev/null || true)"
  crd_short="$(kubectl get crd "$CRD_NAME" -o jsonpath='{.spec.names.shortNames[*]}' 2>/dev/null || true)"
  [[ "$crd_cond" == *"Established=True"* ]] && break
  sleep 2
done
if [[ "$crd_cond" == *"Established=True"* && "$crd_scope" == "Namespaced" && "$crd_short" == *"cfgforge"* ]]; then
  pass "CRD '${CRD_NAME}' has Established=True, scope=${crd_scope}, shortName=${crd_short} (expected: Established=True, Namespaced, cfgforge)"
else
  fail "CRD '${CRD_NAME}' has conditions='${crd_cond:-missing}', scope='${crd_scope:-missing}', shortName='${crd_short:-missing}' (expected: Established=True, Namespaced, cfgforge)"
fi

# 2. 'kubectl explain configforge.spec' succeeds and lists field 'data'
explain_out="$(kubectl explain configforge.spec 2>/dev/null || true)"
if printf '%s\n' "$explain_out" | grep -q 'FIELDS:' && printf '%s\n' "$explain_out" | grep -q 'data'; then
  pass "'kubectl explain configforge.spec' succeeded and lists field 'data' (expected: OpenAPI schema listing 'data')"
else
  fail "'kubectl explain configforge.spec' failed or did not list 'data' field (expected: OpenAPI schema listing 'data')"
fi

# 3. An invalid ConfigForge (spec.data longer than maxLength: 40) is REJECTED by the API server
max_len="$(kubectl get crd "$CRD_NAME" -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.data.maxLength}' 2>/dev/null || true)"
invalid_rejected=0
if [[ "$crd_cond" == *"Established=True"* && -n "$max_len" ]]; then
  if ! kubectl -n "$NS" apply -f - >/dev/null 2>&1 <<'EOF'
apiVersion: lab.example.com/v1
kind: ConfigForge
metadata:
  name: invalid-probe
spec:
  data: "nilai-konfigurasi-ini-sengaja-dibuat-lebih-dari-empat-puluh-karakter-agar-ditolak"
EOF
  then
    invalid_rejected=1
  fi
  kubectl -n "$NS" delete configforge invalid-probe --ignore-not-found >/dev/null 2>&1 || true
fi
if [[ "$invalid_rejected" -eq 1 ]]; then
  pass "Invalid ConfigForge (spec.data > maxLength=${max_len}) was rejected by the API server (expected: rejected by OpenAPI schema validation)"
else
  fail "Invalid ConfigForge was not rejected by OpenAPI validation (maxLength='${max_len:-missing}') (expected: rejected by OpenAPI schema validation)"
fi

# 4. Participant's valid ConfigForge exists in cka-lab20 and is readable
cf_name="$(kubectl -n "$NS" get configforge app-cfg -o jsonpath='{.metadata.name}' 2>/dev/null || true)"
cf_data="$(kubectl -n "$NS" get configforge app-cfg -o jsonpath='{.spec.data}' 2>/dev/null || true)"
if [[ -z "$cf_name" ]]; then
  cf_name="$(kubectl -n "$NS" get configforge -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  cf_data="$(kubectl -n "$NS" get configforge -o jsonpath='{.items[0].spec.data}' 2>/dev/null || true)"
fi
if [[ -n "$cf_name" && -n "$cf_data" && "${#cf_data}" -le 40 ]]; then
  pass "Valid ConfigForge '${NS}/${cf_name}' is accepted and readable with spec.data='${cf_data}' (expected: valid ConfigForge present in ${NS})"
else
  fail "No valid ConfigForge found in '${NS}' (name='${cf_name:-missing}', spec.data='${cf_data:-missing}') (expected: valid ConfigForge present in ${NS})"
fi

# 5. CRD 'ingressroutes.traefik.io' exists (Established=True) and Traefik deployment is Available
ir_crd_cond=""
tr_avail=""
for _ in $(seq 1 "$(ptries get crd "$TRAEFIK_CRD")"); do
  ir_crd_cond="$(kubectl get crd "$TRAEFIK_CRD" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  tr_avail="$(kubectl -n "$TRAEFIK_NS" get deployment traefik -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
  [[ "$ir_crd_cond" == *"Established=True"* && "$tr_avail" == *"Available=True"* ]] && break
  sleep 2
done
if [[ "$ir_crd_cond" == *"Established=True"* && "$tr_avail" == *"Available=True"* ]]; then
  pass "CRD '${TRAEFIK_CRD}' has Established=True and Deployment '${TRAEFIK_NS}/traefik' has Available=True (expected: Established=True and Available=True)"
else
  fail "CRD '${TRAEFIK_CRD}' conditions='${ir_crd_cond:-missing}', Deployment '${TRAEFIK_NS}/traefik' conditions='${tr_avail:-missing}' (expected: Established=True and Available=True)"
fi

# 6. Participant's IngressRoute exists in cka-lab20 with host 'app.lab20.local' and service 'web' (port 80)
ir_name=""
ir_match=""
ir_svc=""
ir_port=""
for _ in $(seq 1 "$(ptries -n "$NS" get ingressroute app-route)"); do
  if kubectl -n "$NS" get ingressroute app-route >/dev/null 2>&1; then
    ir_name="app-route"
  else
    ir_name="$(kubectl -n "$NS" get ingressroutes.traefik.io -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  fi
  if [[ -n "$ir_name" ]]; then
    ir_match="$(kubectl -n "$NS" get ingressroutes.traefik.io "$ir_name" -o jsonpath='{.spec.routes[*].match}' 2>/dev/null || true)"
    ir_svc="$(kubectl -n "$NS" get ingressroutes.traefik.io "$ir_name" -o jsonpath='{.spec.routes[*].services[*].name}' 2>/dev/null || true)"
    ir_port="$(kubectl -n "$NS" get ingressroutes.traefik.io "$ir_name" -o jsonpath='{.spec.routes[*].services[*].port}' 2>/dev/null || true)"
    break
  fi
  sleep 2
done
if [[ -z "$ir_name" ]]; then
  ir_name="$(kubectl -n "$NS" get ingressroutes.traefik.io -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "$ir_name" ]]; then
    ir_match="$(kubectl -n "$NS" get ingressroutes.traefik.io "$ir_name" -o jsonpath='{.spec.routes[*].match}' 2>/dev/null || true)"
    ir_svc="$(kubectl -n "$NS" get ingressroutes.traefik.io "$ir_name" -o jsonpath='{.spec.routes[*].services[*].name}' 2>/dev/null || true)"
    ir_port="$(kubectl -n "$NS" get ingressroutes.traefik.io "$ir_name" -o jsonpath='{.spec.routes[*].services[*].port}' 2>/dev/null || true)"
  fi
fi
if [[ -n "$ir_name" && "$ir_match" == *"app.lab20.local"* && "$ir_svc" == *"web"* && ( "$ir_port" == *"80"* || "$ir_port" == *"http"* ) ]]; then
  pass "IngressRoute '${NS}/${ir_name}' routes match='${ir_match}' to service='${ir_svc}' port='${ir_port}' (expected: Host app.lab20.local -> service web:80)"
else
  fail "IngressRoute in '${NS}' (name='${ir_name:-missing}', match='${ir_match:-missing}', service='${ir_svc:-missing}:${ir_port:-missing}') invalid (expected: Host app.lab20.local -> service web:80)"
fi

# Discover Traefik HTTP NodePort (defaults to 30082 from setup.sh)
np="$(kubectl -n "$TRAEFIK_NS" get svc traefik -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}' 2>/dev/null || true)"
[[ -z "$np" ]] && np="$(kubectl -n "$TRAEFIK_NS" get svc traefik -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"
np="${np:-30082}"

# 7. HTTP through Traefik NodePort with Host: app.lab20.local returns nginx welcome page (bounded poll)
web_body=""
for _ in $(seq 1 "$(ptries -n "$NS" get ingressroutes.traefik.io "${ir_name:-app-route}")"); do
  web_body="$(curl -s --max-time 3 -H 'Host: app.lab20.local' "http://localhost:${np}/" 2>/dev/null || true)"
  if printf '%s\n' "$web_body" | grep -qi "Welcome to nginx"; then
    break
  fi
  sleep 2
done
if printf '%s\n' "$web_body" | grep -qi "Welcome to nginx"; then
  pass "HTTP probe 'curl -H \"Host: app.lab20.local\" http://localhost:${np}/' returned nginx welcome page (expected: 'Welcome to nginx')"
else
  fail "HTTP probe 'curl -H \"Host: app.lab20.local\" http://localhost:${np}/' did not return nginx welcome page (expected: 'Welcome to nginx')"
fi

# 8. After deleting the IngressRoute, the same request no longer returns nginx (404) (bounded poll), then restore
route_gone_status=""
route_gone_body=""
if [[ -n "$ir_name" ]] && printf '%s\n' "$web_body" | grep -qi "Welcome to nginx"; then
  kubectl -n "$NS" get ingressroutes.traefik.io "$ir_name" -o json 2>/dev/null \
    | jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.generation, .metadata.managedFields, .status)' \
    > "$IR_BACKUP" 2>/dev/null || true
  kubectl -n "$NS" delete ingressroutes.traefik.io "$ir_name" --ignore-not-found >/dev/null 2>&1 || true

  for _ in $(seq 1 15); do
    route_gone_status="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 -H 'Host: app.lab20.local' "http://localhost:${np}/" 2>/dev/null || true)"
    route_gone_body="$(curl -s --max-time 3 -H 'Host: app.lab20.local' "http://localhost:${np}/" 2>/dev/null || true)"
    if [[ "$route_gone_status" == "404" ]] && ! printf '%s\n' "$route_gone_body" | grep -qi "Welcome to nginx"; then
      break
    fi
    sleep 2
  done

  # Restore participant's IngressRoute so the cluster remains in solved state after verify.sh finishes
  if [[ -s "$IR_BACKUP" ]]; then
    kubectl apply -f "$IR_BACKUP" >/dev/null 2>&1 || true
    for _ in $(seq 1 15); do
      restored_body="$(curl -s --max-time 3 -H 'Host: app.lab20.local' "http://localhost:${np}/" 2>/dev/null || true)"
      if printf '%s\n' "$restored_body" | grep -qi "Welcome to nginx"; then
        break
      fi
      sleep 2
    done
    rm -f "$IR_BACKUP" >/dev/null 2>&1 || true
  fi
fi
if [[ "$route_gone_status" == "404" ]] && ! printf '%s\n' "$route_gone_body" | grep -qi "Welcome to nginx"; then
  pass "Deleting IngressRoute '${NS}/${ir_name}' caused Traefik to remove the route and return HTTP ${route_gone_status} (expected: HTTP 404 without nginx page)"
else
  fail "After deleting IngressRoute '${NS}/${ir_name:-missing}', probe returned HTTP '${route_gone_status:-none}' (expected: HTTP 404 after active IngressRoute reconciled and deleted)"
fi

# 9. reset.sh exists, is valid bash, deletes namespace cka-lab20 and CRD configforges.lab.example.com, and leaves Traefik installed
reset_ok=0
if [[ -f "$RESET_SCRIPT" ]] && bash -n "$RESET_SCRIPT" >/dev/null 2>&1; then
  if grep -q 'delete namespace' "$RESET_SCRIPT" \
    && grep -q 'configforges.lab.example.com' "$RESET_SCRIPT" \
    && ! grep -Eq 'helm uninstall|delete namespace.*traefik' "$RESET_SCRIPT"; then
    reset_ok=1
  fi
fi
if [[ "$reset_ok" -eq 1 ]]; then
  pass "reset/reset.sh is valid and deletes namespace '${NS}' + CRD '${CRD_NAME}' while keeping Traefik installed (expected: deletes ${NS} and ${CRD_NAME}, keeps Traefik)"
else
  fail "reset/reset.sh missing or does not match documented reset behavior (expected: deletes ${NS} and ${CRD_NAME}, keeps Traefik)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
