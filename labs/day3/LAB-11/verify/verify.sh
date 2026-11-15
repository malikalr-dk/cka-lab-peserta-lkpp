#!/usr/bin/env bash
# LAB-11 verifier: StorageClass (local-path), PVC/PV dynamic provisioning, data survival across pods, and Retain reclaim policy
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="gisp-app"
PVC_NAME="data"
READER_POD="reader"
ANSWER_FILE="/root/lab/lab11-answer.txt"

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

# 1. StorageClass 'local-path' exists
if kubectl get storageclass local-path >/dev/null 2>&1; then
  pass "StorageClass 'local-path' exists (expected: present)"
else
  fail "StorageClass 'local-path' does not exist (expected: present)"
fi

# 2. PVC 'data' in gisp-app exists and is Bound
pvc_phase="$(kubectl -n "$NS" get pvc "$PVC_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
pvc_sc="$(kubectl -n "$NS" get pvc "$PVC_NAME" -o jsonpath='{.spec.storageClassName}' 2>/dev/null || true)"
pv_name="$(kubectl -n "$NS" get pvc "$PVC_NAME" -o jsonpath='{.spec.volumeName}' 2>/dev/null || true)"
if [[ "$pvc_phase" == "Bound" && "$pvc_sc" == "local-path" && -n "$pv_name" ]]; then
  pass "PersistentVolumeClaim '${NS}/${PVC_NAME}' is '${pvc_phase}' on StorageClass '${pvc_sc}' to PV '${pv_name}' (expected: Bound on local-path)"
else
  fail "PersistentVolumeClaim '${NS}/${PVC_NAME}' has phase='${pvc_phase:-missing}', storageClassName='${pvc_sc:-missing}', volumeName='${pv_name:-none}' (expected: Bound on local-path)"
fi

# 3. PV behind 'data' exists and its claimRef matches gisp-app/data
# If PVC was deleted during a Retain demonstration, fall back to searching PVs with claimRef gisp-app/data
if [[ -z "$pv_name" ]]; then
  pv_name="$(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.claimRef.namespace}/{.spec.claimRef.name}{"\n"}{end}' 2>/dev/null | awk '$2 == "gisp-app/data" {print $1; exit}' || true)"
fi
pv_claim_ns="$(kubectl get pv "${pv_name:-none}" -o jsonpath='{.spec.claimRef.namespace}' 2>/dev/null || true)"
pv_claim_name="$(kubectl get pv "${pv_name:-none}" -o jsonpath='{.spec.claimRef.name}' 2>/dev/null || true)"
if [[ -n "$pv_name" && "$pv_claim_ns" == "$NS" && "$pv_claim_name" == "$PVC_NAME" ]]; then
  pass "PersistentVolume '${pv_name}' exists and has claimRef '${pv_claim_ns}/${pv_claim_name}' (expected: '${NS}/${PVC_NAME}')"
else
  fail "PersistentVolume '${pv_name:-none}' claimRef is '${pv_claim_ns:-none}/${pv_claim_name:-none}' (expected: '${NS}/${PVC_NAME}')"
fi

# 4. File /data/proof.txt inside 'reader' pod contains 'hello-cka'
printf 'INFO: waiting up to 20s for Pod %s/%s to be Running...\n' "$NS" "$READER_POD"
for _ in $(seq 1 10); do
  r_phase="$(kubectl -n "$NS" get pod "$READER_POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  [[ "$r_phase" == "Running" || "$r_phase" == "Succeeded" ]] && break
  sleep 2
done

proof_content="$(kubectl -n "$NS" exec "$READER_POD" -- cat /data/proof.txt 2>/dev/null | tr -d '\r' || true)"
if [[ "$proof_content" == *"hello-cka"* ]]; then
  pass "Pod '${NS}/${READER_POD}' file '/data/proof.txt' contains 'hello-cka' (expected: 'hello-cka')"
else
  fail "Pod '${NS}/${READER_POD}' file '/data/proof.txt' returned '${proof_content:-empty/unreachable}' (expected: 'hello-cka')"
fi

# 5. /root/lab/lab11-answer.txt exists and names the PV
# Match either the currently bound PV or any pvc-* name recorded in the file if the participant recreated the PVC after testing deletion
ans_text=""
if [[ -f "$ANSWER_FILE" ]]; then
  ans_text="$(cat "$ANSWER_FILE" 2>/dev/null || true)"
fi
if [[ -n "$ans_text" && -n "$pv_name" ]] && printf '%s\n' "$ans_text" | grep -qF "$pv_name"; then
  pass "Answer file '${ANSWER_FILE}' exists and records active PV name '${pv_name}' (expected: PV name present)"
elif [[ -n "$ans_text" ]] && printf '%s\n' "$ans_text" | grep -Eq 'pvc-[0-9a-f-]{36}'; then
  recorded_pv="$(printf '%s\n' "$ans_text" | grep -Eo 'pvc-[0-9a-f-]{36}' | head -1)"
  pass "Answer file '${ANSWER_FILE}' exists and records provisioned PV name '${recorded_pv}' (expected: pvc-<uuid>)"
else
  fail "Answer file '${ANSWER_FILE}' is missing or does not contain the provisioned PV name '${pv_name:-pvc-<uuid>}'"
fi

# 6. PV reclaim policy is Retain OR the answer file states the deletion outcome
pv_reclaim="$(kubectl get pv "${pv_name:-none}" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null || true)"
ans_outcome_ok=0
if printf '%s\n' "$ans_text" | grep -Eqi 'Released|Retain|tidak.*hapus|not.*deleted|tetap.*ada|survive'; then
  ans_outcome_ok=1
fi

if [[ "$pv_reclaim" == "Retain" && "$ans_outcome_ok" -eq 1 ]]; then
  pass "PV '${pv_name}' has persistentVolumeReclaimPolicy='${pv_reclaim}' and '${ANSWER_FILE}' explains the PVC deletion outcome (expected: Retain + outcome explained)"
elif [[ "$pv_reclaim" == "Retain" ]]; then
  pass "PV '${pv_name}' has persistentVolumeReclaimPolicy='${pv_reclaim}' (expected: Retain)"
elif [[ "$ans_outcome_ok" -eq 1 ]]; then
  pass "Answer file '${ANSWER_FILE}' states the PV deletion outcome under Retain policy (expected: Retain or outcome explained)"
else
  fail "PV '${pv_name:-none}' has persistentVolumeReclaimPolicy='${pv_reclaim:-missing}' and '${ANSWER_FILE}' lacks deletion outcome explanation (expected: Retain)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
