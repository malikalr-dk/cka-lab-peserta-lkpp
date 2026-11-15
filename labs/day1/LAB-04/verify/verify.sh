#!/usr/bin/env bash
# LAB-04 verifier: worker join, CNI (Calico), and DNS resolution
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

PROBE_POD="lab04-dns-probe"

cleanup() {
  kubectl delete pod "$PROBE_POD" --ignore-not-found --wait=false >/dev/null 2>&1 || true
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

# 1. 3 nodes Ready
nodes_out="$(kubectl get nodes --no-headers 2>/dev/null || true)"
ready_nodes="$(printf '%s\n' "$nodes_out" | awk '$2 == "Ready" {count++} END {print count+0}')"
if [[ "$ready_nodes" -eq 3 ]]; then
  pass "cluster nodes Ready count is ${ready_nodes} (expected: 3)"
else
  fail "cluster nodes Ready count is ${ready_nodes} (expected: 3)"
fi

# 2. calico-node DaemonSet has 3 ready
# The DS controller reports numberReady a few seconds after the pods are Running;
# poll briefly instead of failing a participant who waited correctly.
for _ in $(seq 1 20); do
  calico_probe="$(kubectl -n kube-system get daemonset calico-node -o jsonpath='{.status.numberReady}' 2>/dev/null || true)"
  [[ "${calico_probe:-0}" -eq 3 ]] && break
  sleep 3
done
calico_ready="$(kubectl -n kube-system get daemonset calico-node -o jsonpath='{.status.numberReady}' 2>/dev/null || true)"
if [[ -z "$calico_ready" ]]; then
  calico_ready="$(kubectl -n calico-system get daemonset calico-node -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
fi
if [[ "${calico_ready:-0}" -eq 3 ]]; then
  pass "DaemonSet 'calico-node' numberReady is ${calico_ready} (expected: 3)"
else
  fail "DaemonSet 'calico-node' numberReady is ${calico_ready:-0} (expected: 3)"
fi

# 3. kube-system coredns pods are Running
# coredns restarts once Calico brings the pod network up; poll before judging.
for _ in $(seq 1 30); do
  coredns_probe="$(kubectl -n kube-system get pods --no-headers 2>/dev/null | awk '$1 ~ /^coredns/ && $3 == "Running" {c++} END {print c+0}')"
  coredns_all="$(kubectl -n kube-system get pods --no-headers 2>/dev/null | awk '$1 ~ /^coredns/ {c++} END {print c+0}')"
  [[ "${coredns_probe:-0}" -ge 1 && "${coredns_probe:-0}" -eq "${coredns_all:-0}" ]] && break
  sleep 3
done
coredns_out="$(kubectl -n kube-system get pods -l k8s-app=kube-dns --no-headers 2>/dev/null || true)"
if [[ -z "$coredns_out" ]]; then
  coredns_out="$(kubectl -n kube-system get pods --no-headers 2>/dev/null | awk '$1 ~ /^coredns/')"
fi
coredns_total="$(printf '%s\n' "$coredns_out" | awk 'NF > 0 {count++} END {print count+0}')"
coredns_running="$(printf '%s\n' "$coredns_out" | awk '$3 == "Running" {count++} END {print count+0}')"
if [[ "$coredns_total" -ge 1 && "$coredns_running" -eq "$coredns_total" ]]; then
  pass "kube-system 'coredns' pods Running is ${coredns_running}/${coredns_total} (expected: all Running, >=1)"
else
  fail "kube-system 'coredns' pods Running is ${coredns_running}/${coredns_total} (expected: all Running, >=1)"
fi

# 4. Throwaway busybox:1.37 pod resolves kubernetes.default.svc.cluster.local
# No 'kubectl run --rm -i': with stdin not a TTY (ssh, cron, CI) the attach stream
# never closes and the verifier hangs. Create, wait for Succeeded, then read the log.
kubectl delete pod "$PROBE_POD" --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl run "$PROBE_POD" --image=busybox:1.37 --image-pull-policy=IfNotPresent --restart=Never \
  --command -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 || true
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$PROBE_POD" --timeout=90s >/dev/null 2>&1 || true
dns_out="$(kubectl logs "$PROBE_POD" 2>&1 || true)"
if printf '%s\n' "$dns_out" | grep -q "kubernetes.default.svc.cluster.local" && printf '%s\n' "$dns_out" | grep -Eq "Address.*: *[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"; then
  pass "pod '${PROBE_POD}' (image 'busybox:1.37') nslookup resolved 'kubernetes.default.svc.cluster.local' (expected: resolved IP address)"
else
  fail "pod '${PROBE_POD}' (image 'busybox:1.37') failed to resolve 'kubernetes.default.svc.cluster.local' (expected: resolved IP address)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
