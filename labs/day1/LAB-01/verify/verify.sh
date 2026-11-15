#!/usr/bin/env bash
# LAB-01 verifier: imperative Pod creation, client-side manifest generation, exec proof, and report file
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="gisp-app"
POD_MANIFEST="/root/lab/lab01-pod.yaml"
REPORT_FILE="/root/lab/lab01-report.txt"

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

# 1. Namespace 'gisp-app' exists and is Active
ns_phase="$(kubectl get namespace "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ "$ns_phase" == "Active" ]]; then
  pass "Namespace '${NS}' exists and status.phase=${ns_phase} (expected: Active)"
else
  fail "Namespace '${NS}' status.phase='${ns_phase:-missing}' (expected: Active)"
fi

# 2. Pod 'web' is Running in namespace 'gisp-app' with image 'nginx:1.27-alpine'
web_phase=""
web_img=""
for _ in $(seq 1 15); do
  web_phase="$(kubectl -n "$NS" get pod web -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  web_img="$(kubectl -n "$NS" get pod web -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)"
  [[ "$web_phase" == "Running" ]] && break
  sleep 2
done
if [[ "$web_phase" == "Running" && ( "$web_img" == "nginx:1.27-alpine" || "$web_img" == "docker.io/library/nginx:1.27-alpine" ) ]]; then
  pass "Pod '${NS}/web' is ${web_phase} with image '${web_img}' (expected: Running, nginx:1.27-alpine)"
else
  fail "Pod '${NS}/web' has phase='${web_phase:-missing}', image='${web_img:-missing}' (expected: Running, nginx:1.27-alpine)"
fi

# 3. Pod 'web2' is Running in namespace 'gisp-app' with image 'nginx:1.29-alpine'
web2_phase=""
web2_img=""
for _ in $(seq 1 15); do
  web2_phase="$(kubectl -n "$NS" get pod web2 -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  web2_img="$(kubectl -n "$NS" get pod web2 -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)"
  [[ "$web2_phase" == "Running" ]] && break
  sleep 2
done
if [[ "$web2_phase" == "Running" && ( "$web2_img" == "nginx:1.29-alpine" || "$web2_img" == "docker.io/library/nginx:1.29-alpine" ) ]]; then
  pass "Pod '${NS}/web2' is ${web2_phase} with image '${web2_img}' (expected: Running, nginx:1.29-alpine)"
else
  fail "Pod '${NS}/web2' has phase='${web2_phase:-missing}', image='${web2_img:-missing}' (expected: Running, nginx:1.29-alpine)"
fi

# 4. /root/lab/lab01-pod.yaml exists, resolves to Pod/web2, and 'kubectl apply --dry-run=server -f' exits 0
if [[ -f "$POD_MANIFEST" ]]; then
  resolved_name="$(kubectl -n "$NS" apply --dry-run=server -f "$POD_MANIFEST" -o name 2>/dev/null | tr -d '[:space:]' || true)"
  kubectl -n "$NS" apply --dry-run=server -f "$POD_MANIFEST" >/dev/null 2>&1
  dryrun_rc=$?
  if [[ "$dryrun_rc" -eq 0 && "$resolved_name" == "pod/web2" ]]; then
    pass "Manifest '${POD_MANIFEST}' resolves to '${resolved_name}' and server-side dry-run apply exited 0 (expected: pod/web2, exit 0)"
  else
    fail "Manifest '${POD_MANIFEST}' resolved to '${resolved_name:-invalid}' with server dry-run rc=${dryrun_rc} (expected: pod/web2, exit 0)"
  fi
else
  fail "Manifest '${POD_MANIFEST}' does not exist (expected: generated Pod/web2 YAML manifest)"
fi

# 5. The nginx version reported inside 'web2' is 1.29.x (HTTP proof via wget -qO- http://127.0.0.1/, fall back to nginx -v)
web2_ver_out=""
http_ok=0
if [[ "$web2_phase" == "Running" ]]; then
  for _ in $(seq 1 10); do
    http_body="$(kubectl -n "$NS" exec web2 -- wget -qO- http://127.0.0.1/ 2>/dev/null || true)"
    if [[ -n "$http_body" ]]; then
      http_ok=1
    fi
    if printf '%s\n' "$http_body" | grep -Eq '1\.29\.[0-9]+'; then
      web2_ver_out="$http_body"
      break
    fi
    ver_Fallback="$(kubectl -n "$NS" exec web2 -- nginx -v 2>&1 | tr -d '\r' || true)"
    if printf '%s\n' "$ver_Fallback" | grep -Eq '1\.29\.[0-9]+'; then
      web2_ver_out="$ver_Fallback"
      break
    fi
    sleep 2
  done
fi
if [[ -n "$web2_ver_out" ]] && printf '%s\n' "$web2_ver_out" | grep -Eq '1\.29\.[0-9]+'; then
  pass "Pod '${NS}/web2' serves HTTP (http_ok=${http_ok}) and reports nginx 1.29.x: '${web2_ver_out}' (expected: 1.29.x)"
else
  fail "Pod '${NS}/web2' did not report nginx 1.29.x via exec (got: '${web2_ver_out:-none}') (expected: 1.29.x)"
fi

# 6. /root/lab/lab01-report.txt has both keys non-empty and web2_served matches 1.29
if [[ -f "$REPORT_FILE" ]]; then
  rep_web_img="$(awk -F'=' '/^web_image=/ {sub(/^[^=]*=/, ""); print; exit}' "$REPORT_FILE" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  rep_web2_srv="$(awk -F'=' '/^web2_served=/ {sub(/^[^=]*=/, ""); print; exit}' "$REPORT_FILE" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [[ -n "$rep_web_img" && -n "$rep_web2_srv" && "$rep_web_img" == "nginx:1.27-alpine" ]] && printf '%s\n' "$rep_web2_srv" | grep -q '1\.29'; then
    pass "Report '${REPORT_FILE}' has web_image='${rep_web_img}' and web2_served='${rep_web2_srv}' matching 1.29"
  else
    fail "Report '${REPORT_FILE}' has web_image='${rep_web_img:-empty}', web2_served='${rep_web2_srv:-empty}' (expected: web_image=nginx:1.27-alpine and web2_served matching 1.29)"
  fi
else
  fail "Report file '${REPORT_FILE}' does not exist (expected: web_image=nginx:1.27-alpine and web2_served=<1.29.x>)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
