#!/usr/bin/env bash
# LAB-16 verifier: HPA 'demo' targets Deployment/demo at 50% CPU, proven by a real scale-out and
# a real scale-in. Behaviour-based on purpose — the image name is never asserted, so a BYO image
# (/root/lab/lab14-image.txt) passes the same checks; the image is printed as INFO only.
# Every async step is a bounded retry: HPA scale-out needs one metrics window plus a scale
# decision, and a single-shot check is a guaranteed false FAIL.
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="cka-lab14"
DECL="/root/lab/lab14-image.txt"
DEF_PORT="9898"
DEF_PATH="/"

# Generous on purpose: default HPA scale-up after a fresh load pod is 30-90s on this cluster,
# but a cold metrics-server can take a full 60s window before the HPA sees any number at all.
SCALE_WINDOW_SECONDS=180
# Scale-in is asserted because the task makes behavior.scaleDown.stabilizationWindowSeconds=10
# mandatory; with that patch the drop lands in ~30-60s. The default 300s window is why the
# patch is required rather than optional.
SCALE_IN_WINDOW_SECONDS=120
SCALE_POLL_INTERVAL=3
READY_WINDOW_SECONDS=60
VERIFY_LOAD_POD="lab14-verify-load"
PARTICIPANT_LOAD_POD="load-generator"

cleanup() {
  kubectl -n "$NS" delete pod "$VERIFY_LOAD_POD" --ignore-not-found --wait=false >/dev/null 2>&1 || true
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

trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# jsonpath returns "" for an unset field; arithmetic on that aborts under 'set -u'.
num() {
  local v="${1:-}"
  if [[ "$v" =~ ^[0-9]+$ ]]; then printf '%s' "$v"; else printf '0'; fi
}

# BYO declaration: only the load URL depends on it, never an assertion on the image name.
LOAD_PORT="$DEF_PORT"
LOAD_PATH="$DEF_PATH"
DECL_IMAGE=""
if [[ -f "$DECL" ]]; then
  while IFS='=' read -r key value || [[ -n "${key:-}" ]]; do
    key="$(trim "${key:-}")"
    value="$(trim "${value:-}")"
    case "$key" in
      image) [[ -n "$value" ]] && DECL_IMAGE="$value" ;;
      port)  [[ -n "$value" ]] && LOAD_PORT="$value" ;;
      path)  [[ -n "$value" ]] && LOAD_PATH="$value" ;;
      ""|\#*) : ;;
    esac
  done < "$DECL"
fi
if [[ ! "$LOAD_PORT" =~ ^[0-9]+$ ]] || [[ "$LOAD_PORT" -lt 1 ]] || [[ "$LOAD_PORT" -gt 65535 ]]; then
  printf 'WARN: port=%s in %s is not a valid port (expected: 1-65535); using %s\n' \
    "$LOAD_PORT" "$DECL" "$DEF_PORT"
  LOAD_PORT="$DEF_PORT"
fi
[[ "$LOAD_PATH" == /* ]] || LOAD_PATH="/$LOAD_PATH"
LOAD_URL="http://demo.${NS}.svc.cluster.local:${LOAD_PORT}${LOAD_PATH}"
printf 'INFO: declaration %s image=%s (INFO only, never asserted), load target %s\n' \
  "$DECL" "${DECL_IMAGE:-default podinfo:6.7.1}" "$LOAD_URL"
dep_image="$(kubectl -n "$NS" get deployment demo -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
printf 'INFO: Deployment %s/demo image=%s (INFO only, never asserted)\n' "$NS" "${dep_image:-missing}"

# 1. Metrics API answers — pod metrics for this namespace, node metrics as the fallback.
top_out=""
top_source=""
for attempt in $(seq 1 30); do
  top_out="$(kubectl -n "$NS" top pods --no-headers 2>/dev/null || true)"
  top_source="kubectl -n ${NS} top pods"
  if [[ -z "$top_out" ]]; then
    top_out="$(kubectl top nodes --no-headers 2>/dev/null || true)"
    top_source="kubectl top nodes"
  fi
  if [[ -n "$top_out" ]]; then
    break
  fi
  printf 'INFO: metrics API pending (%d/30)\n' "$attempt"
  sleep 2
done
if [[ -n "$top_out" ]]; then
  pass "Metrics API responds: '${top_source}' returned $(printf '%s\n' "$top_out" | wc -l | tr -d ' ') row(s) (expected: metrics available)"
else
  fail "Metrics API did not answer 'kubectl top nodes' or 'kubectl -n ${NS} top pods' within 60s (expected: metrics available)"
fi

# 2. Deployment 'demo' is Ready and carries resources.requests.cpu
#    HPA cannot compute a percentage without the request; the value itself is not locked.
dep_uid="$(kubectl -n "$NS" get deployment demo -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
req_cpu="$(kubectl -n "$NS" get deployment demo -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)"
dep_ready=0
dep_ready_note=""
if [[ -n "$dep_uid" ]]; then
  for attempt in $(seq 1 20); do
    spec_r="$(num "$(kubectl -n "$NS" get deployment demo -o jsonpath='{.spec.replicas}' 2>/dev/null || true)")"
    ready_r="$(num "$(kubectl -n "$NS" get deployment demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)")"
    [[ "$spec_r" -lt 1 ]] && spec_r=1
    if [[ "$ready_r" -ge 1 && "$ready_r" -eq "$spec_r" ]]; then
      dep_ready=1
      dep_ready_note="readyReplicas=${ready_r}/${spec_r}"
      break
    fi
    dep_ready_note="readyReplicas=${ready_r}/${spec_r}"
    printf 'INFO: Deployment readiness poll %d/20: %s\n' "$attempt" "$dep_ready_note"
    sleep 3
  done
else
  dep_ready_note="Deployment missing"
fi
if [[ "$dep_ready" -eq 1 && -n "$req_cpu" ]]; then
  pass "Deployment '${NS}/demo' is Ready (${dep_ready_note}) with resources.requests.cpu='${req_cpu}' (expected: Ready with requests.cpu set)"
else
  fail "Deployment '${NS}/demo' is Ready=${dep_ready} (${dep_ready_note:-no observation}) requests.cpu='${req_cpu:-missing}' (expected: Ready with requests.cpu set)"
fi

# 3. HPA 'demo' targets Deployment/demo with min=1, max=4, CPU target 50%
hpa_uid="$(kubectl -n "$NS" get hpa demo -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
hpa_ref="$(kubectl -n "$NS" get hpa demo -o jsonpath='{.spec.scaleTargetRef.kind}/{.spec.scaleTargetRef.name}' 2>/dev/null || true)"
hpa_min="$(kubectl -n "$NS" get hpa demo -o jsonpath='{.spec.minReplicas}' 2>/dev/null || true)"
hpa_max="$(kubectl -n "$NS" get hpa demo -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || true)"
hpa_cpu_v2="$(kubectl -n "$NS" get hpa demo -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}' 2>/dev/null || true)"
hpa_cpu_v1="$(kubectl -n "$NS" get hpa demo -o jsonpath='{.spec.targetCPUUtilizationPercentage}' 2>/dev/null || true)"
hpa_cpu="${hpa_cpu_v2:-$hpa_cpu_v1}"
if [[ -n "$hpa_uid" && "$hpa_ref" == "Deployment/demo" && "${hpa_min:-1}" == "1" && "$hpa_max" == "4" && "$hpa_cpu" == "50" ]]; then
  pass "HorizontalPodAutoscaler '${NS}/demo' targets ${hpa_ref} min=${hpa_min:-1} max=${hpa_max} cpu=${hpa_cpu}% (expected: Deployment/demo, min=1, max=4, cpu=50%)"
else
  fail "HorizontalPodAutoscaler '${NS}/demo' target='${hpa_ref:-missing}' min=${hpa_min:-missing} max=${hpa_max:-missing} cpu=${hpa_cpu:-missing}% (expected: Deployment/demo, min=1, max=4, cpu=50%)"
fi

# 4. Under load, Deployment 'demo' holds more than one ready replica.
# Gate the wait on the objects existing: three minutes of silence on a missing HPA reads as a
# hung verifier to the trainer, which is worse than an immediate, clear FAIL.
max_ready="$(num "$(kubectl -n "$NS" get deployment demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)")"
max_hpa_cur=0
scaled_up=0
scale_note=""

if [[ -z "$hpa_uid" || -z "$dep_uid" ]]; then
  scale_note="not attempted: HPA or Deployment missing"
else
  cleanup
  load_pod_gone=0
  for attempt in $(seq 1 15); do
    if ! kubectl -n "$NS" get pod "$VERIFY_LOAD_POD" >/dev/null 2>&1; then
      load_pod_gone=1
      break
    fi
    printf 'INFO: previous verifier load Pod deletion pending (%d/15)\n' "$attempt"
    sleep 2
  done

  # 4 parallel wget loops against the Service: one sequential loop burns ~68m of a 100m
  # request, too close to the 50% target, and the HPA then flaps 1<->2 instead of holding.
  load_cmd="for i in 1 2 3 4; do (while true; do wget -q -O- ${LOAD_URL} >/dev/null 2>&1; done) & done; wait"
  if [[ "$load_pod_gone" -ne 1 ]]; then
    scale_note="not attempted: previous verifier load Pod still terminating after 30s"
  elif ! kubectl -n "$NS" run "$VERIFY_LOAD_POD" --image=busybox:1.37 --image-pull-policy=IfNotPresent \
    --restart=Never --command -- sh -c "$load_cmd" >/dev/null; then
    scale_note="not attempted: could not create verifier load Pod"
  else
    load_running=0
    for attempt in $(seq 1 15); do
      load_phase="$(kubectl -n "$NS" get pod "$VERIFY_LOAD_POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
      if [[ "$load_phase" == "Running" ]]; then
        load_running=1
        break
      fi
      [[ "$load_phase" == "Failed" || "$load_phase" == "Succeeded" ]] && break
      printf 'INFO: verifier load Pod poll %d/15: phase=%s\n' "$attempt" "${load_phase:-unknown}"
      sleep 2
    done

    if [[ "$load_running" -ne 1 ]]; then
      scale_note="not attempted: verifier load Pod never reached Running"
    else
      poll_max=$((SCALE_WINDOW_SECONDS / SCALE_POLL_INTERVAL))
      printf 'INFO: load running; polling up to %ds for readyReplicas>1...\n' "$SCALE_WINDOW_SECONDS"
      for attempt in $(seq 1 "$poll_max"); do
        ready_r="$(num "$(kubectl -n "$NS" get deployment demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)")"
        des_r="$(num "$(kubectl -n "$NS" get deployment demo -o jsonpath='{.status.replicas}' 2>/dev/null || true)")"
        cur_r="$(num "$(kubectl -n "$NS" get hpa demo -o jsonpath='{.status.currentReplicas}' 2>/dev/null || true)")"
        cpu_r="$(kubectl -n "$NS" get hpa demo -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null || true)"
        [[ "$ready_r" -gt "$max_ready" ]] && max_ready="$ready_r"
        [[ "$cur_r" -gt "$max_hpa_cur" ]] && max_hpa_cur="$cur_r"
        if [[ $((attempt % 5)) -eq 1 ]]; then
          printf 'INFO: scale-out poll %d/%d: ready=%s replicas=%s hpaCurrent=%s cpu=%s%%\n' \
            "$attempt" "$poll_max" "$ready_r" "$des_r" "${cur_r:-0}" "${cpu_r:-unknown}"
        fi
        if [[ "$ready_r" -gt 1 ]]; then
          scaled_up=1
          scale_note="ready=${ready_r} after ~$((attempt * SCALE_POLL_INTERVAL))s of load (hpaCurrent=${cur_r:-0}, cpu=${cpu_r:-unknown}%)"
          break
        fi
        sleep "$SCALE_POLL_INTERVAL"
      done
      [[ "$scaled_up" -eq 1 ]] || scale_note="peak readyReplicas=${max_ready} after ${SCALE_WINDOW_SECONDS}s of load"
    fi
  fi
fi

if [[ "$scaled_up" -eq 1 ]]; then
  pass "Deployment '${NS}/demo' scaled out under load: ${scale_note} (expected: readyReplicas>1 within ${SCALE_WINDOW_SECONDS}s of load start)"
else
  fail "Deployment '${NS}/demo' never reached readyReplicas>1 within ${SCALE_WINDOW_SECONDS}s of load start (peak ready=${max_ready}, peak hpaCurrent=${max_hpa_cur}, ${scale_note:-no observation}) (expected: readyReplicas>1 within ${SCALE_WINDOW_SECONDS}s of load start)"
fi

# 5. Scale-in: load removed, Deployment back to a single ready replica.
# Both load pods go: the verifier's own and the participant's load-generator, because a leftover
# generator keeps the CPU above target and would turn a correct answer into a FAIL.
if [[ "$scaled_up" -ne 1 ]]; then
  fail "Scale-in not observed: scale-out never happened, so there is nothing to scale back from (${scale_note:-no observation}) (expected: readyReplicas back to 1 within ${SCALE_IN_WINDOW_SECONDS}s after the load stops)"
else
  cleanup
  kubectl -n "$NS" delete pod "$PARTICIPANT_LOAD_POD" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  for attempt in $(seq 1 15); do
    if ! kubectl -n "$NS" get pod "$VERIFY_LOAD_POD" >/dev/null 2>&1 \
      && ! kubectl -n "$NS" get pod "$PARTICIPANT_LOAD_POD" >/dev/null 2>&1; then
      break
    fi
    printf 'INFO: load Pod termination pending (%d/15)\n' "$attempt"
    sleep 2
  done

  poll_max=$((SCALE_IN_WINDOW_SECONDS / SCALE_POLL_INTERVAL))
  printf 'INFO: load removed; polling up to %ds for readyReplicas back to 1...\n' "$SCALE_IN_WINDOW_SECONDS"
  scaled_in=0
  scale_in_note=""
  for attempt in $(seq 1 "$poll_max"); do
    ready_r="$(num "$(kubectl -n "$NS" get deployment demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)")"
    spec_r="$(num "$(kubectl -n "$NS" get deployment demo -o jsonpath='{.spec.replicas}' 2>/dev/null || true)")"
    cur_r="$(num "$(kubectl -n "$NS" get hpa demo -o jsonpath='{.status.currentReplicas}' 2>/dev/null || true)")"
    cpu_r="$(kubectl -n "$NS" get hpa demo -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null || true)"
    scale_in_note="ready=${ready_r} spec=${spec_r} hpaCurrent=${cur_r} cpu=${cpu_r:-unknown}%"
    if [[ $((attempt % 5)) -eq 1 ]]; then
      printf 'INFO: scale-in poll %d/%d: %s\n' "$attempt" "$poll_max" "$scale_in_note"
    fi
    if [[ "$ready_r" -le 1 && "$spec_r" -le 1 ]]; then
      scaled_in=1
      scale_in_note="${scale_in_note} after ~$((attempt * SCALE_POLL_INTERVAL))s without load"
      break
    fi
    sleep "$SCALE_POLL_INTERVAL"
  done

  if [[ "$scaled_in" -eq 1 ]]; then
    pass "Deployment '${NS}/demo' scaled back in: ${scale_in_note} (expected: readyReplicas back to 1 within ${SCALE_IN_WINDOW_SECONDS}s after the load stops)"
  else
    fail "Deployment '${NS}/demo' did not return to 1 ready replica within ${SCALE_IN_WINDOW_SECONDS}s after the load stopped (${scale_in_note:-no observation}) (expected: readyReplicas back to 1 within ${SCALE_IN_WINDOW_SECONDS}s after the load stops)"
  fi
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
