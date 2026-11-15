#!/usr/bin/env bash
# LAB-15 verifier: NetworkPolicy default-deny on app=demo plus an allow-list from role=client
# on the declared port only. Behaviour-based: the image name is never asserted (BYO), only
# that allowed traffic passes and denied traffic (wrong source pod, wrong port) fails.
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="cka-lab13"
DECL="/root/lab/lab13-image.txt"
DEFAULT_PORT="9898"
DEFAULT_PATH="/healthz"

# Same declaration the starter renders from; last occurrence of the key wins.
decl_get() {
  [[ -f "$DECL" ]] || return 1
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$DECL" |
    tail -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//'
}

PORT="$DEFAULT_PORT"
PROBE_PATH="$DEFAULT_PATH"
if [[ -f "$DECL" ]]; then
  v="$(decl_get port || true)"
  if [[ -n "${v:-}" ]]; then
    if [[ "$v" =~ ^[0-9]+$ ]]; then
      PORT="$v"
    else
      printf 'INFO: port=%s di %s bukan angka; memakai default %s\n' "$v" "$DECL" "$DEFAULT_PORT"
    fi
  fi
  v="$(decl_get path || true)"
  if [[ -n "${v:-}" ]]; then
    if [[ "$v" == /* ]]; then
      PROBE_PATH="$v"
    else
      printf 'INFO: path=%s di %s tidak dimulai dengan /; memakai default %s\n' "$v" "$DECL" "$DEFAULT_PATH"
    fi
  fi
fi
# Port the policy is not supposed to open; never the declared one.
ALT_PORT="8080"
[[ "$PORT" == "8080" ]] && ALT_PORT="8081"

URL="http://demo:${PORT}${PROBE_PATH}"
ALT_URL="http://demo:${ALT_PORT}/"

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

# Bounded retry count: <N> polls only when the object exists, 1 when it does not, so a
# missing object fails immediately instead of polling in silence for minutes.
retries() {
  local n="$1"
  shift
  kubectl "$@" >/dev/null 2>&1 && echo "$n" || echo 1
}

# probe <pod> <url> — sets PROBE_RC and PROBE_BYTES. -T 3 makes a dropped path fail in ~3s.
probe() {
  local out rc
  out="$(kubectl -n "$NS" exec "pod/$1" -- timeout 10 wget -qO- -T 3 "$2" 2>/dev/null)"
  rc=$?
  PROBE_RC="$rc"
  PROBE_BYTES="${#out}"
}

# Wait up to 60s for the starter workloads (a fresh namespace after reset.sh needs more
# than 30s even with cached images).
for _ in $(seq 1 "$(retries 30 -n "$NS" get deployment demo)"); do
  demo_r="$(kubectl -n "$NS" get deployment demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  client_r="$(kubectl -n "$NS" get deployment client -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  intruder_p="$(kubectl -n "$NS" get pod intruder -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  [[ "${demo_r:-0}" -ge 1 && "${client_r:-0}" -ge 1 && "${intruder_p:-}" == "Running" ]] && break
  sleep 2
done

demo_ready="$(kubectl -n "$NS" get deployment demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
client_ready="$(kubectl -n "$NS" get deployment client -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
intruder_phase="$(kubectl -n "$NS" get pod intruder -o jsonpath='{.status.phase}' 2>/dev/null || true)"
demo_pod="$(kubectl -n "$NS" get pods -l app=demo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
demo_ip="$(kubectl -n "$NS" get pods -l app=demo -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || true)"
client_pod="$(kubectl -n "$NS" get pods -l role=client -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
demo_image="$(kubectl -n "$NS" get deployment demo -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"

printf 'INFO: target Deployment demo image=%s (informational only, not asserted); probing port %s path %s, denied port %s\n' \
  "${demo_image:-unknown}" "$PORT" "$PROBE_PATH" "$ALT_PORT"

# 1. Starter workloads are Ready: Deployment demo, Deployment client, Pod intruder
if [[ "${demo_ready:-0}" -ge 1 && "${client_ready:-0}" -ge 1 && "$intruder_phase" == "Running" && -n "$demo_pod" ]]; then
  pass "Workloads in '${NS}' Ready: demo=${demo_ready} (${demo_pod}, IP ${demo_ip}), client=${client_ready}, intruder=${intruder_phase} (expected: demo and client Ready, intruder Running)"
else
  fail "Workloads in '${NS}' not Ready: demo=${demo_ready:-0}, client=${client_ready:-0}, intruder=${intruder_phase:-missing} (expected: demo and client Ready, intruder Running)"
fi

# 2. At least one NetworkPolicy in the namespace selects Pods with app=demo
np_match=""
np_list=""
for _ in $(seq 1 "$(retries 5 -n "$NS" get namespace "$NS")"); do
  np_list="$(kubectl -n "$NS" get networkpolicy -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)"
  np_match=""
  for np in $np_list; do
    # empty podSelector ("" + "|" + "") selects every pod in the namespace, demo included
    sel="$(kubectl -n "$NS" get networkpolicy "$np" -o jsonpath='{.spec.podSelector.matchLabels.app}{"|"}{.spec.podSelector.matchExpressions}' 2>/dev/null || true)"
    case "$sel" in
      demo\|*) np_match="${np} (podSelector app=demo)" ;;
      '|')     np_match="${np} (empty podSelector: selects every pod, demo included)" ;;
    esac
    [[ -n "$np_match" ]] && break
  done
  [[ -n "$np_match" ]] && break
  sleep 2
done
if [[ -n "$np_match" ]]; then
  pass "NetworkPolicy in '${NS}' selects app=demo: ${np_match} (expected: a policy whose podSelector covers app=demo)"
else
  fail "No NetworkPolicy in '${NS}' selects app=demo (policies found: ${np_list:-none}) (expected: a policy whose podSelector covers app=demo)"
fi

# 3. HTTP from role=client to the declared port/path SUCCEEDS (poll for policy programming)
allowed=0
PROBE_RC=""
PROBE_BYTES=0
if [[ -z "$client_pod" || -z "$demo_pod" ]]; then
  fail "HTTP GET ${URL} from client pod not attempted: client=${client_pod:-missing}, demo=${demo_pod:-missing} (expected: 2xx from pod '${NS}/${client_pod:-client}' to ${URL})"
else
  for _ in $(seq 1 10); do
    probe "$client_pod" "$URL"
    [[ "$PROBE_RC" -eq 0 ]] && { allowed=1; break; }
    sleep 2
  done
  if [[ "$allowed" -eq 1 ]]; then
    pass "HTTP GET ${URL} from '${NS}/${client_pod}' (role=client) succeeded, ${PROBE_BYTES} bytes (expected: request to the declared port/path allowed from role=client)"
  else
    fail "HTTP GET ${URL} from '${NS}/${client_pod}' (role=client) failed (exit ${PROBE_RC:-?}) (expected: allowed — cek Service demo, label app=demo, dan aturan from podSelector role=client ports TCP ${PORT})"
  fi
fi

# 4. HTTP from role=intruder to the same port/path is BLOCKED
intruder_blocked=0
intruder_control="$(kubectl -n "$NS" exec pod/intruder -- sh -c 'echo ok' 2>/dev/null || true)"
if [[ "$intruder_phase" != "Running" || "$intruder_control" != "ok" ]]; then
  fail "Cannot measure the deny: '${NS}/intruder' phase=${intruder_phase:-missing}, exec control='${intruder_control:-failed}' (expected: intruder Running so HTTP from role=intruder to ${URL} can be blocked)"
else
  for _ in $(seq 1 10); do
    probe intruder "$URL"
    [[ "$PROBE_RC" -ne 0 ]] && { intruder_blocked=1; break; }
    sleep 2
  done
  if [[ "$intruder_blocked" -eq 1 ]]; then
    pass "HTTP GET ${URL} from '${NS}/intruder' (role=intruder) failed (exit ${PROBE_RC}) — blocked (expected: blocked, source label role=intruder is not in the allow-list)"
  else
    fail "HTTP GET ${URL} from '${NS}/intruder' (role=intruder) succeeded (exit ${PROBE_RC}) (expected: blocked, source label role=intruder is not in the allow-list)"
  fi
fi

# 5. HTTP from role=client to a port other than the declared one is BLOCKED
alt_blocked=0
alt_elapsed=0
PROBE_RC=""
if [[ -z "$client_pod" ]]; then
  fail "HTTP GET ${ALT_URL} from client pod not attempted: no pod with label role=client (expected: blocked on port ${ALT_PORT} while ${URL} stays allowed)"
else
  for _ in $(seq 1 5); do
    t0=$SECONDS
    probe "$client_pod" "$ALT_URL"
    [[ "$PROBE_RC" -ne 0 ]] && { alt_blocked=1; alt_elapsed=$((SECONDS - t0)); break; }
    sleep 2
  done
  if [[ "$alt_blocked" -eq 1 ]]; then
    pass "HTTP GET ${ALT_URL} from '${NS}/${client_pod}' (role=client) failed after ${alt_elapsed}s (exit ${PROBE_RC}) — only TCP ${PORT} is open (expected: blocked on any port other than ${PORT})"
  else
    fail "HTTP GET ${ALT_URL} from '${NS}/${client_pod}' (role=client) succeeded (exit ${PROBE_RC}) (expected: blocked on any port other than ${PORT} — the ingress rule must restrict ports to TCP ${PORT})"
  fi
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
