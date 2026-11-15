#!/usr/bin/env bash
# LAB-01 verifier: satu Pod, image diperbarui di tempat, satu container berjalan.
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="gisp-app"
REPORT_FILE="/root/lab/lab01-report.txt"
UPDATED_IMAGE="nginx:1.29-alpine"

passed=0
total=0

pass() { passed=$((passed + 1)); total=$((total + 1)); printf 'PASS: %s\n' "$*"; }
fail() { total=$((total + 1)); printf 'FAIL: %s\n' "$*"; }
img_matches() { [[ "$1" == "$2" || "$1" == "docker.io/library/$2" ]]; }

# 1. Namespace 'gisp-app' ada dan Active
ns_phase="$(kubectl get namespace "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ "$ns_phase" == "Active" ]]; then
  pass "Namespace '${NS}' exists and status.phase=${ns_phase} (expected: Active)"
else
  fail "Namespace '${NS}' status.phase='${ns_phase:-missing}' (expected: Active)"
fi

# 2. Pod 'web' Running dengan spec image nginx:1.29-alpine
web_phase=""
web_img=""
for _ in $(seq 1 15); do
  web_phase="$(kubectl -n "$NS" get pod web -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  web_img="$(kubectl -n "$NS" get pod web -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)"
  [[ "$web_phase" == "Running" ]] && img_matches "$web_img" "$UPDATED_IMAGE" && break
  sleep 2
done
if [[ "$web_phase" == "Running" ]] && img_matches "$web_img" "$UPDATED_IMAGE"; then
  pass "Pod '${NS}/web' is ${web_phase} with spec image '${web_img}' (expected: Running, ${UPDATED_IMAGE})"
else
  fail "Pod '${NS}/web' phase='${web_phase:-missing}', spec image='${web_img:-missing}' (expected: Running, ${UPDATED_IMAGE})"
fi

# 3. Image yang benar-benar dipakai container juga 1.29, bukan hanya berubah di spec
web_actual=""
for _ in $(seq 1 15); do
  web_actual="$(kubectl -n "$NS" get pod web -o jsonpath='{.status.containerStatuses[0].image}' 2>/dev/null || true)"
  img_matches "$web_actual" "$UPDATED_IMAGE" && break
  sleep 2
done
if img_matches "$web_actual" "$UPDATED_IMAGE"; then
  pass "Container '${NS}/web' benar-benar memakai image '${web_actual}' (expected: ${UPDATED_IMAGE})"
else
  fail "Container '${NS}/web' masih memakai image '${web_actual:-none}' (expected: ${UPDATED_IMAGE})"
fi

# 4. Versi di dalam container setelah update
web_ver_out=""
if [[ "$web_phase" == "Running" ]]; then
  for _ in $(seq 1 10); do
    web_ver_out="$(kubectl -n "$NS" exec web -- nginx -v 2>&1 | tr -d '\r' || true)"
    printf '%s\n' "$web_ver_out" | grep -Eq '1\.29\.[0-9]+' && break
    sleep 2
  done
fi
if printf '%s\n' "$web_ver_out" | grep -Eq '1\.29\.[0-9]+'; then
  pass "Pod '${NS}/web' melaporkan nginx 1.29.x dari dalam container: '${web_ver_out}' (expected: 1.29.x)"
else
  fail "Pod '${NS}/web' tidak melaporkan 1.29.x (got: '${web_ver_out:-none}') (expected: 1.29.x)"
fi

# 5. Report mencatat image sebelum dan sesudah
if [[ -f "$REPORT_FILE" ]]; then
  rep_before="$(awk -F'=' '/^web_image_before=/ {sub(/^[^=]*=/, ""); print; exit}' "$REPORT_FILE" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  rep_after="$(awk -F'=' '/^web_image_after=/ {sub(/^[^=]*=/, ""); print; exit}' "$REPORT_FILE" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [[ "$rep_before" == "nginx:1.27-alpine" && "$rep_after" == "$UPDATED_IMAGE" ]]; then
    pass "Report '${REPORT_FILE}' mencatat sebelum='${rep_before}' dan sesudah='${rep_after}'"
  else
    fail "Report '${REPORT_FILE}' sebelum='${rep_before:-empty}', sesudah='${rep_after:-empty}' (expected: nginx:1.27-alpine lalu ${UPDATED_IMAGE})"
  fi
else
  fail "Report file '${REPORT_FILE}' tidak ada (expected: web_image_before dan web_image_after)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
