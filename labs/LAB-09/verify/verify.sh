#!/usr/bin/env bash
# LAB-09 verifier: Service + Endpoints + cluster DNS + HTTP behaviour for Deployment demo.
# Behaviour-based on purpose: the Deployment image is never asserted, so a class may bring its own
# image declared in /root/lab/lab09-image.txt (image=<ref>, port=<n>, path=<path>). Without that
# file the defaults are podinfo:6.7.1 on port 9898 with /healthz.
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="cka-lab09"
DECL="/root/lab/lab09-image.txt"
DEF_IMAGE="docker.io/stefanprodan/podinfo:6.7.1"
DEF_PORT="9898"
DEF_PATH="/healthz"
PROBE_POD="lab09-verify-probe"
FQDN="demo.${NS}.svc.cluster.local"

# ---- target: declaration file when present, defaults otherwise -------------------------------
IMAGE="$DEF_IMAGE"
PORT="$DEF_PORT"
HEALTH_PATH="$DEF_PATH"
decl_error=""
if [[ -f "$DECL" ]]; then
  d_img="$(sed -n 's/^[[:space:]]*image=//p' "$DECL" | tail -1 | tr -d '[:space:]')"
  d_port="$(sed -n 's/^[[:space:]]*port=//p' "$DECL" | tail -1 | tr -d '[:space:]')"
  d_path="$(sed -n 's/^[[:space:]]*path=//p' "$DECL" | tail -1 | tr -d '[:space:]')"
  [[ -n "$d_img" ]] && IMAGE="$d_img"
  [[ -n "$d_port" ]] && PORT="$d_port"
  [[ -n "$d_path" ]] && HEALTH_PATH="$d_path"
  if [[ -z "$d_img" || -z "$d_port" || -z "$d_path" ]]; then
    decl_error="baris tidak lengkap (image='${d_img}' port='${d_port}' path='${d_path}')"
  elif ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    decl_error="port bukan angka ('${PORT}')"
    PORT="$DEF_PORT"
  fi
fi
[[ "$HEALTH_PATH" == /* ]] || HEALTH_PATH="/${HEALTH_PATH}"

# The verifier's own probe pod is only created when the starter client pod is gone.
cleanup() {
  kubectl -n "$NS" delete pod "$PROBE_POD" --ignore-not-found --wait=false >/dev/null 2>&1 || true
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

num() { [[ "${1:-}" =~ ^[0-9]+$ ]] && printf '%s' "$1" || printf '0'; }
# Retry budget gated on existence: 15x2s while the object is there, a single attempt when it is
# not, so a starter-state run answers in seconds instead of minutes of silence.
ptries() { kubectl "$@" >/dev/null 2>&1 && echo 15 || echo 1; }
# The remote runner is a Linux CP, but never let a missing coreutils binary fake a FAIL.
command -v timeout >/dev/null 2>&1 || timeout() { shift; "$@"; }

if [[ -f "$DECL" ]]; then
  printf 'INFO: deklarasi %s -> image=%s port=%s path=%s\n' "$DECL" "$IMAGE" "$PORT" "$HEALTH_PATH"
else
  printf 'INFO: %s tidak ada -> default image=%s port=%s path=%s\n' "$DECL" "$IMAGE" "$PORT" "$HEALTH_PATH"
fi
if [[ -n "$decl_error" ]]; then
  fail "Deklarasi BYO '${DECL}' tidak valid: ${decl_error}; verifier melanjutkan dengan port=${PORT} path=${HEALTH_PATH} (expected: image=<ref>, port=<angka>, path=<path>)"
fi

# 1. Deployment demo is Ready (readyReplicas == 1)
ready_rep=0
tries="$(ptries -n "$NS" get deployment demo)"
for i in $(seq 1 "$tries"); do
  ready_rep="$(kubectl -n "$NS" get deployment demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "$(num "$ready_rep")" -eq 1 ]] && break
  (( i < tries )) && sleep 2
done
observed_image="$(kubectl -n "$NS" get deployment demo -o jsonpath='{.spec.template.spec.containers[*].image}' 2>/dev/null || true)"
[[ -n "$observed_image" ]] && printf 'INFO: Deployment %s/demo memakai image %s (nama image tidak dinilai)\n' "$NS" "$observed_image"
if [[ "$(num "$ready_rep")" -eq 1 ]]; then
  pass "Deployment '${NS}/demo' has readyReplicas=$(num "$ready_rep") (expected: 1 ready replica)"
else
  fail "Deployment '${NS}/demo' has readyReplicas=$(num "$ready_rep") (expected: 1 ready replica)"
fi

# 2. Service demo exists, type ClusterIP, on the declared port
svc_type=""
svc_port=""
svc_ip=""
svc_tries="$(ptries -n "$NS" get service demo)"
for i in $(seq 1 "$svc_tries"); do
  svc_type="$(kubectl -n "$NS" get service demo -o jsonpath='{.spec.type}' 2>/dev/null || true)"
  svc_port="$(kubectl -n "$NS" get service demo -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)"
  svc_ip="$(kubectl -n "$NS" get service demo -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)"
  [[ "$svc_type" == "ClusterIP" && "$svc_port" == "$PORT" && -n "$svc_ip" && "$svc_ip" != "None" ]] && break
  (( i < svc_tries )) && sleep 2
done
if [[ "$svc_type" == "ClusterIP" && "$svc_port" == "$PORT" && -n "$svc_ip" && "$svc_ip" != "None" ]]; then
  pass "Service '${NS}/demo' has type=${svc_type}, clusterIP=${svc_ip}, port=${svc_port} (expected: ClusterIP on port ${PORT})"
else
  fail "Service '${NS}/demo' has type=${svc_type:-missing}, clusterIP=${svc_ip:-missing}, port=${svc_port:-missing} (expected: ClusterIP on port ${PORT})"
fi

# 3. Endpoints (or the EndpointSlice) for Service demo holds at least one ready address
ep_ips=""
for i in $(seq 1 "$svc_tries"); do
  ep_ips="$(kubectl -n "$NS" get endpoints demo -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
  if [[ -z "${ep_ips// /}" ]]; then
    ep_ips="$(kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=demo \
      -o jsonpath='{.items[*].endpoints[*].addresses[*]}' 2>/dev/null || true)"
  fi
  [[ -n "${ep_ips// /}" ]] && break
  (( i < svc_tries )) && sleep 2
done
ep_count="$(printf '%s' "${ep_ips:-}" | wc -w | tr -d ' ')"
if [[ "$(num "$ep_count")" -ge 1 ]]; then
  pass "Endpoints for Service '${NS}/demo' list $(num "$ep_count") ready address(es) [${ep_ips}] (expected: >=1 ready address)"
else
  fail "Endpoints for Service '${NS}/demo' list 0 addresses [${ep_ips:-none}] (expected: >=1 ready address)"
fi

# 4 & 5 run from inside the namespace: the starter client pod when it is Running, otherwise a
# temporary probe pod with the same busybox image.
url="http://${FQDN}:${PORT}${HEALTH_PATH}"
exec_pod=""
client_phase="$(kubectl -n "$NS" get pod client -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ "$client_phase" == "Running" ]]; then
  exec_pod="client"
  printf 'INFO: probe DNS/HTTP dari pod klien %s/client\n' "$NS"
else
  printf 'INFO: pod %s/client=%s; membuat %s untuk probe DNS/HTTP\n' "$NS" "${client_phase:-missing}" "$PROBE_POD"
  cat <<EOF | kubectl -n "$NS" apply -f - >/dev/null 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: ${PROBE_POD}
  namespace: ${NS}
  labels:
    role: lab09-verify
spec:
  restartPolicy: Never
  containers:
    - name: probe
      image: busybox:1.37
      imagePullPolicy: IfNotPresent
      command: ["sh", "-c", "sleep 3600"]
EOF
  for i in $(seq 1 15); do
    [[ "$(kubectl -n "$NS" get pod "$PROBE_POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)" == "Running" ]] && break
    (( i < 15 )) && sleep 2
  done
  [[ "$(kubectl -n "$NS" get pod "$PROBE_POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)" == "Running" ]] && exec_pod="$PROBE_POD"
fi

# 4. Cluster DNS resolves the Service FQDN from inside a pod
dns_ips=""
if [[ -n "$exec_pod" ]]; then
  for i in $(seq 1 "$svc_tries"); do
    dns_out="$(timeout 20 kubectl -n "$NS" exec "pod/${exec_pod}" -- nslookup "$FQDN" 2>&1 || true)"
    dns_ips="$(printf '%s\n' "$dns_out" | awk '/^Name:/{seen=1} seen && /^Address/ {print $NF}' | tr '\n' ' ' | sed 's/ *$//')"
    [[ -n "${dns_ips// /}" ]] && break
    (( i < svc_tries )) && sleep 2
  done
fi
if [[ -n "${dns_ips// /}" ]]; then
  pass "DNS lookup '${FQDN}' from pod '${NS}/${exec_pod}' resolved [${dns_ips}] (expected: >=1 A record)"
else
  fail "DNS lookup '${FQDN}' from pod '${NS}/${exec_pod:-none}' did not resolve (expected: >=1 A record)"
fi

# 5. HTTP GET of the declared health path through the Service returns 200
http_code=""
http_exit=""
if [[ -n "$exec_pod" ]]; then
  for i in $(seq 1 "$svc_tries"); do
    http_out="$(timeout 20 kubectl -n "$NS" exec "pod/${exec_pod}" -- \
      wget -S -O /dev/null -T 5 "$url" 2>&1; printf 'LAB09_EXIT=%s\n' "$?")"
    http_code="$(printf '%s\n' "$http_out" | grep -oiE 'HTTP/[0-9.]+ [0-9]{3}' | tail -1 | awk '{print $2}')"
    http_exit="$(printf '%s\n' "$http_out" | sed -n 's/^LAB09_EXIT=//p' | tail -1)"
    [[ "$http_code" == "200" ]] && break
    (( i < svc_tries )) && sleep 2
  done
fi
if [[ "$http_code" == "200" ]]; then
  pass "HTTP GET '${url}' from pod '${NS}/${exec_pod}' returned 200 (expected: HTTP 200)"
elif [[ -z "$http_code" && "${http_exit:-1}" == "0" ]]; then
  # busybox wget exits non-zero on 4xx/5xx, so exit 0 still means the path answered 2xx.
  pass "HTTP GET '${url}' from pod '${NS}/${exec_pod}' exited 0 with an unreadable status line (expected: HTTP 200)"
else
  fail "HTTP GET '${url}' from pod '${NS}/${exec_pod:-none}' returned HTTP ${http_code:-000} (expected: HTTP 200)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
