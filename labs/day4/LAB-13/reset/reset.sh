#!/usr/bin/env bash
# LAB-13 reset:
#   1. Restore /etc/kubernetes/manifests/kube-apiserver.yaml on the control-plane node from /root/lab18-backup/
#   2. Wait for kube-apiserver to answer
#   3. Restore /var/lib/kubelet/config.yaml on the worker node(s) from /root/lab18-backup/ and restart kubelet
#   4. Wait for all nodes to be Ready
#   5. Re-inject Fault A so LAB-13 starts in its initial broken state (idempotent and safe to run twice)
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
FAULT_SCRIPT="${SCRIPT_DIR}/../fault/fault.sh"
BACKUP_DIR="/root/lab18-backup"
NODE_CACHE_FILE="${BACKUP_DIR}/node-cache.env"
APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
APISERVER_BACKUP="${BACKUP_DIR}/kube-apiserver.yaml.bak"
SSH_KEY="/root/.ssh/lab-key"
SSH_OPTS=(
  -n
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=5
  -o LogLevel=ERROR
)

# 1. Restore control-plane kube-apiserver manifest if backup exists or if broken flag is present
if [[ -s "$APISERVER_BACKUP" ]] && ! grep -q -- '--lab18-broken-flag' "$APISERVER_BACKUP"; then
  cp -p "$APISERVER_BACKUP" "${APISERVER_MANIFEST}.restore.tmp"
  sync
  mv -f "${APISERVER_MANIFEST}.restore.tmp" "$APISERVER_MANIFEST"
  printf 'INFO: restored %s from %s\n' "$APISERVER_MANIFEST" "$APISERVER_BACKUP"
elif [[ -f "$APISERVER_MANIFEST" ]] && grep -q -- '--lab18-broken-flag' "$APISERVER_MANIFEST"; then
  sed '/--lab18-broken-flag/d' "$APISERVER_MANIFEST" >"${APISERVER_MANIFEST}.restore.tmp"
  mv -f "${APISERVER_MANIFEST}.restore.tmp" "$APISERVER_MANIFEST"
  printf 'INFO: removed --lab18-broken-flag from %s\n' "$APISERVER_MANIFEST"
fi

# Clean up any accidental backup files participants may have left inside /etc/kubernetes/manifests/
find /etc/kubernetes/manifests/ -maxdepth 1 -type f ! -name 'etcd.yaml' ! -name 'kube-apiserver.yaml' \
  ! -name 'kube-controller-manager.yaml' ! -name 'kube-scheduler.yaml' -delete 2>/dev/null || true

# 2. Wait up to 60s for kube-apiserver to answer
printf 'INFO: waiting up to 60s for kube-apiserver to respond...\n'
for _ in $(seq 1 30); do
  if kubectl --request-timeout=5s get nodes >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# 3. Resolve worker nodes from kubectl get nodes (and cached worker if present) and restore kubelet config
worker_ips=()
if [[ -f "$NODE_CACHE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$NODE_CACHE_FILE"
  if [[ -n "${CACHED_WORKER_IP:-}" ]]; then
    worker_ips+=("$CACHED_WORKER_IP")
  fi
fi

while IFS= read -r ip; do
  if [[ -n "$ip" ]]; then
    already_seen=0
    for existing in "${worker_ips[@]:-}"; do
      [[ "$existing" == "$ip" ]] && already_seen=1
    done
    [[ "$already_seen" -eq 0 ]] && worker_ips+=("$ip")
  fi
done < <(
  kubectl --request-timeout=5s get nodes -l '!node-role.kubernetes.io/control-plane' --sort-by=.metadata.name \
    -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}' 2>/dev/null || true
)

for w_ip in "${worker_ips[@]:-}"; do
  [[ -z "$w_ip" ]] && continue
  printf 'INFO: restoring kubelet config and restarting kubelet on worker %s...\n' "$w_ip"
  ssh "${SSH_OPTS[@]}" "root@${w_ip}" "bash -c '
    set -uo pipefail
    KUBELET_CFG=\"/var/lib/kubelet/config.yaml\"
    BACKUP_CFG=\"/root/lab18-backup/kubelet-config.yaml.bak\"

    if [[ -s \"\$BACKUP_CFG\" ]] && grep -q \"cgroupDriver: systemd\" \"\$BACKUP_CFG\"; then
      cp -p \"\$BACKUP_CFG\" \"\${KUBELET_CFG}.restore.tmp\"
      sync
      mv -f \"\${KUBELET_CFG}.restore.tmp\" \"\$KUBELET_CFG\"
    elif [[ -f \"\$KUBELET_CFG\" ]]; then
      sed -i \"s/cgroupDriver: cgroupfs/cgroupDriver: systemd/\" \"\$KUBELET_CFG\"
    fi

    systemctl daemon-reload
    systemctl restart kubelet
  '" || true
done

# 4. Wait up to 60s for all nodes and control-plane components to be Ready
printf 'INFO: waiting up to 60s for all cluster nodes to be Ready before re-injecting Fault A...\n'
for _ in $(seq 1 30); do
  nodes_raw="$(kubectl --request-timeout=5s get nodes --no-headers 2>/dev/null || true)"
  if [[ -n "$nodes_raw" ]]; then
    not_ready="$(printf '%s\n' "$nodes_raw" | awk '$2 != "Ready" {c++} END {print c+0}')"
    total_nodes="$(printf '%s\n' "$nodes_raw" | awk 'NF > 0 {c++} END {print c+0}')"
    if [[ "$total_nodes" -ge 2 && "$not_ready" -eq 0 ]]; then
      break
    fi
  fi
  sleep 2
done

# 5. Re-inject Fault A so LAB-13 is ready for the next participant
if [[ -f "$FAULT_SCRIPT" ]]; then
  bash "$FAULT_SCRIPT" a
elif [[ -f "labs/LAB-13/fault/fault.sh" ]]; then
  bash "labs/LAB-13/fault/fault.sh" a
else
  # Inline fallback when reset.sh is piped over SSH (bash -s < reset.sh) without fault.sh on local path
  target_worker="$(kubectl --request-timeout=5s get nodes -l '!node-role.kubernetes.io/control-plane' --sort-by=.metadata.name -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || printf '%s' "${CACHED_WORKER_NODE:-}")"
  target_ip="$(kubectl --request-timeout=5s get node "$target_worker" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || printf '%s' "${CACHED_WORKER_IP:-}")"
  if [[ -z "$target_worker" || -z "$target_ip" ]]; then
    printf 'ERROR: unable to resolve target worker node to re-inject Fault A\n' >&2
    exit 1
  fi
  ssh "${SSH_OPTS[@]}" "root@${target_ip}" "bash -c '
    set -euo pipefail
    mkdir -p /root/lab18-backup
    if [[ ! -s /root/lab18-backup/kubelet-config.yaml.bak ]] || grep -q \"cgroupDriver: systemd\" /var/lib/kubelet/config.yaml; then
      cp -p /var/lib/kubelet/config.yaml /root/lab18-backup/kubelet-config.yaml.bak
    fi
    sed -i \"s/cgroupDriver: systemd/cgroupDriver: cgroupfs/\" /var/lib/kubelet/config.yaml
    systemctl stop kubelet
  '"
  printf 'FAULT A INJECTED: %s (%s) — /var/lib/kubelet/config.yaml set to cgroupDriver: cgroupfs and kubelet stopped\n' "$target_worker" "$target_ip"
fi

printf 'Reset complete: cluster restored from /root/lab18-backup/ and Fault A re-injected for LAB-13\n'
exit 0
