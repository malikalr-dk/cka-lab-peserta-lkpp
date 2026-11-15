#!/usr/bin/env bash
# LAB-13 verifier: cluster & node troubleshooting (Fault A: worker kubelet cgroupDriver, Fault B: kube-apiserver manifest)
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

BACKUP_DIR="/root/lab18-backup"
NODE_CACHE_FILE="${BACKUP_DIR}/node-cache.env"
SSH_KEY="/root/.ssh/lab-key"
SSH_OPTS=(
  -n
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=5
  -o LogLevel=ERROR
)

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

# 1. No file in /etc/kubernetes/manifests/ contains 'lab18-broken-flag'
bad_manifests="$(grep -RIl 'lab18-broken-flag' /etc/kubernetes/manifests/ 2>/dev/null || true)"
if [[ -z "$bad_manifests" ]]; then
  pass "No static pod manifest in /etc/kubernetes/manifests/ contains 'lab18-broken-flag' (expected: clean manifests)"
else
  bad_list="$(printf '%s' "$bad_manifests" | tr '\n' ' ')"
  fail "Static pod manifest(s) in /etc/kubernetes/manifests/ still contain 'lab18-broken-flag': ${bad_list% } (expected: flag removed)"
fi

# 2. crictl ps on the control-plane node lists a running kube-apiserver container (poll up to 60s)
printf 'INFO: polling up to 60s for running kube-apiserver container via crictl ps and API server readiness...\n'
apiserver_cid=""
api_reachable=0
for _ in $(seq 1 30); do
  apiserver_cid="$(crictl ps --name kube-apiserver -q 2>/dev/null | head -n 1 || true)"
  if [[ -z "$apiserver_cid" ]]; then
    apiserver_cid="$(crictl ps 2>/dev/null | awk '/kube-apiserver/ {print $1; exit}' || true)"
  fi
  if kubectl --request-timeout=5s get nodes >/dev/null 2>&1; then
    api_reachable=1
  fi
  if [[ -n "$apiserver_cid" && "$api_reachable" -eq 1 ]]; then
    break
  fi
  sleep 2
done

if [[ -n "$apiserver_cid" ]]; then
  pass "Control-plane container runtime 'crictl ps' lists running kube-apiserver container (id=${apiserver_cid}) (expected: running kube-apiserver)"
else
  fail "Control-plane container runtime 'crictl ps' does not list a running kube-apiserver container after 60s (expected: running kube-apiserver)"
fi

# 3. Every node in the cluster is Ready (poll up to 60s while kubelet / API server settles)
all_nodes_ready=0
nodes_summary=""
for _ in $(seq 1 30); do
  nodes_raw="$(kubectl --request-timeout=5s get nodes --no-headers 2>/dev/null || true)"
  if [[ -n "$nodes_raw" ]]; then
    api_reachable=1
    not_ready_count="$(printf '%s\n' "$nodes_raw" | awk '$2 != "Ready" {c++} END {print c+0}')"
    node_count="$(printf '%s\n' "$nodes_raw" | awk 'NF > 0 {c++} END {print c+0}')"
    nodes_summary="$(printf '%s\n' "$nodes_raw" | awk '{printf "%s=%s ", $1, $2}')"
    if [[ "$node_count" -ge 2 && "$not_ready_count" -eq 0 ]]; then
      all_nodes_ready=1
      break
    fi
  fi
  sleep 2
done

if [[ "$all_nodes_ready" -eq 1 ]]; then
  pass "All cluster nodes are Ready (${nodes_summary% }) (expected: all nodes Ready)"
elif [[ "$api_reachable" -eq 0 ]]; then
  fail "Kubernetes API server is unreachable (kubectl --request-timeout=5s get nodes failed); cannot verify node Ready status (expected: API server reachable and all nodes Ready)"
else
  fail "Not all cluster nodes are Ready (${nodes_summary:-none}) (expected: all nodes Ready)"
fi

# 4. kube-system static pods for kube-apiserver, kube-scheduler, kube-controller-manager are Running
cp_pods_ok=0
cp_pods_summary=""
if [[ "$api_reachable" -eq 1 ]]; then
  for _ in $(seq 1 15); do
    apiserver_phase="$(kubectl --request-timeout=5s -n kube-system get pods -l component=kube-apiserver -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)"
    scheduler_phase="$(kubectl --request-timeout=5s -n kube-system get pods -l component=kube-scheduler -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)"
    controller_phase="$(kubectl --request-timeout=5s -n kube-system get pods -l component=kube-controller-manager -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)"
    cp_pods_summary="kube-apiserver=${apiserver_phase:-missing}, kube-scheduler=${scheduler_phase:-missing}, kube-controller-manager=${controller_phase:-missing}"
    if [[ "$apiserver_phase" == "Running" && "$scheduler_phase" == "Running" && "$controller_phase" == "Running" ]]; then
      cp_pods_ok=1
      break
    fi
    sleep 2
  done
fi

if [[ "$cp_pods_ok" -eq 1 ]]; then
  pass "Control-plane pods in kube-system are Running (${cp_pods_summary}) (expected: all Running)"
elif [[ "$api_reachable" -eq 0 ]]; then
  fail "Cannot verify kube-system control-plane pods because API server is unreachable within 5s timeout (expected: kube-apiserver, kube-scheduler, kube-controller-manager Running)"
else
  fail "One or more kube-system control-plane pods are not Running (${cp_pods_summary}) (expected: all Running)"
fi

# Resolve worker nodes (name:ip pairs) dynamically from kubectl get nodes, with cache fallback if API server is down
worker_entries=()
if [[ "$api_reachable" -eq 1 ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && worker_entries+=("$line")
  done < <(
    kubectl --request-timeout=5s get nodes -l '!node-role.kubernetes.io/control-plane' --sort-by=.metadata.name \
      -o jsonpath='{range .items[*]}{.metadata.name}:{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}' 2>/dev/null || true
  )
fi

if [[ "${#worker_entries[@]}" -eq 0 && -f "$NODE_CACHE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$NODE_CACHE_FILE"
  if [[ -n "${CACHED_WORKER_NODE:-}" && -n "${CACHED_WORKER_IP:-}" ]]; then
    worker_entries+=("${CACHED_WORKER_NODE}:${CACHED_WORKER_IP}")
  fi
fi

# 5. systemctl is-active kubelet on every worker is 'active'
if [[ "${#worker_entries[@]}" -eq 0 ]]; then
  fail "Could not resolve worker nodes from API server or cache to check 'systemctl is-active kubelet' (expected: active on all workers)"
else
  kubelet_all_active=1
  kubelet_states=""
  for entry in "${worker_entries[@]}"; do
    w_name="${entry%%:*}"
    w_ip="${entry#*:}"
    w_state="$(ssh "${SSH_OPTS[@]}" "root@${w_ip}" 'systemctl is-active kubelet 2>/dev/null || true' 2>/dev/null || printf 'unreachable')"
    w_state="${w_state//$'\r'/}"
    kubelet_states+="${w_name}(${w_ip})=${w_state:-inactive} "
    if [[ "$w_state" != "active" ]]; then
      kubelet_all_active=0
    fi
  done
  if [[ "$kubelet_all_active" -eq 1 ]]; then
    pass "Service 'kubelet' is active on all worker nodes (${kubelet_states% }) (expected: active)"
  else
    fail "Service 'kubelet' is not active on all worker nodes (${kubelet_states% }) (expected: active)"
  fi
fi

# 6. Worker's /var/lib/kubelet/config.yaml contains 'cgroupDriver: systemd'
if [[ "${#worker_entries[@]}" -eq 0 ]]; then
  fail "Could not resolve worker nodes from API server or cache to check /var/lib/kubelet/config.yaml (expected: cgroupDriver: systemd)"
else
  cgroup_all_systemd=1
  cgroup_states=""
  for entry in "${worker_entries[@]}"; do
    w_name="${entry%%:*}"
    w_ip="${entry#*:}"
    w_driver="$(ssh "${SSH_OPTS[@]}" "root@${w_ip}" "awk '/^[[:space:]]*cgroupDriver:/ {print \$2; exit}' /var/lib/kubelet/config.yaml 2>/dev/null || true" 2>/dev/null || printf 'unreachable')"
    w_driver="${w_driver//$'\r'/}"
    cgroup_states+="${w_name}=${w_driver:-missing} "
    if [[ "$w_driver" != "systemd" ]]; then
      cgroup_all_systemd=0
    fi
  done
  if [[ "$cgroup_all_systemd" -eq 1 ]]; then
    pass "Worker /var/lib/kubelet/config.yaml has cgroupDriver: systemd (${cgroup_states% }) (expected: systemd)"
  else
    fail "Worker /var/lib/kubelet/config.yaml does not have cgroupDriver: systemd (${cgroup_states% }) (expected: systemd)"
  fi
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
