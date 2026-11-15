#!/usr/bin/env bash
# LAB-12 verifier: End-to-end mini project (ConfigMap, PVC, Deployment 3 replicas, Service, Ingress)
# Deliberately not 'set -e': a failing assertion must print, not abort.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
  printf 'INFO: KUBECONFIG not set; falling back to %s\n' "$KUBECONFIG"
fi

NS="cka-lab12"

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

# 1. ConfigMap 'app-config' exists in cka-lab12 with GREETING=halo-lab12
cm_val="$(kubectl -n "$NS" get configmap app-config -o jsonpath='{.data.GREETING}' 2>/dev/null || true)"
if [[ "$cm_val" == "halo-lab12" ]]; then
  pass "ConfigMap '${NS}/app-config' has data.GREETING='${cm_val}' (expected: 'halo-lab12')"
else
  fail "ConfigMap '${NS}/app-config' has data.GREETING='${cm_val:-missing}' (expected: 'halo-lab12')"
fi

# 2. PVC 'portal-data' exists in cka-lab12, storageClassName=local-path, status=Bound
pvc_phase="$(kubectl -n "$NS" get pvc portal-data -o jsonpath='{.status.phase}' 2>/dev/null || true)"
pvc_sc="$(kubectl -n "$NS" get pvc portal-data -o jsonpath='{.spec.storageClassName}' 2>/dev/null || true)"
pvc_req="$(kubectl -n "$NS" get pvc portal-data -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || true)"
if [[ "$pvc_phase" == "Bound" && "$pvc_sc" == "local-path" && "$pvc_req" == "1Gi" ]]; then
  pass "PersistentVolumeClaim '${NS}/portal-data' is '${pvc_phase}' (storageClassName='${pvc_sc}', storage='${pvc_req}') (expected: Bound, local-path, 1Gi)"
else
  fail "PersistentVolumeClaim '${NS}/portal-data' has phase='${pvc_phase:-missing}', storageClassName='${pvc_sc:-missing}', storage='${pvc_req:-missing}' (expected: Bound, local-path, 1Gi)"
fi

# 3. Deployment 'portal' exists with nginx:1.27-alpine and 3/3 ready replicas
printf 'INFO: waiting up to 30s for Deployment %s/portal to have 3 ready replicas...\n' "$NS"
for _ in $(seq 1 10); do
  r_rep="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "${r_rep:-0}" -eq 3 ]] && break
  sleep 3
done

spec_rep="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
ready_rep="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
dep_img="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
if [[ "$spec_rep" == "3" && "$ready_rep" == "3" && ( "$dep_img" == "nginx:1.27-alpine" || "$dep_img" == "docker.io/library/nginx:1.27-alpine" ) ]]; then
  pass "Deployment '${NS}/portal' has replicas=${ready_rep}/${spec_rep} Ready and image='${dep_img}' (expected: 3/3 Ready, nginx:1.27-alpine)"
else
  fail "Deployment '${NS}/portal' has replicas=${ready_rep:-0}/${spec_rep:-0} Ready and image='${dep_img:-missing}' (expected: 3/3 Ready, nginx:1.27-alpine)"
fi

# 4. Deployment 'portal' env comes from ConfigMap 'app-config' AND GREETING=halo-lab12 is in the running container env
envfrom_cm="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].configMapRef.name}' 2>/dev/null || true)"
env_cm="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.spec.template.spec.containers[0].env[*].valueFrom.configMapKeyRef.name}' 2>/dev/null || true)"
cm_ref_ok=0
for ref in $envfrom_cm $env_cm; do
  if [[ "$ref" == "app-config" ]]; then
    cm_ref_ok=1
  fi
done

first_pod="$(kubectl -n "$NS" get pods -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.ownerReferences[0].name}{"\n"}{end}' 2>/dev/null | awk '$2 ~ /^portal-/ {print $1; exit}' || true)"
pod_greeting=""
if [[ -n "$first_pod" ]]; then
  pod_greeting="$(kubectl -n "$NS" exec "$first_pod" -- printenv GREETING 2>/dev/null | tr -d '\r\n' || true)"
fi

if [[ "$cm_ref_ok" -eq 1 && "$pod_greeting" == "halo-lab12" ]]; then
  pass "Deployment '${NS}/portal' sources env from ConfigMap 'app-config' and container env GREETING='${pod_greeting}' (expected: from 'app-config', 'halo-lab12')"
else
  fail "Deployment '${NS}/portal' ConfigMap ref_ok=${cm_ref_ok} and container env GREETING='${pod_greeting:-missing}' (expected: sourced from 'app-config', value 'halo-lab12')"
fi

# 5. Deployment 'portal' mounts PVC 'portal-data' at /usr/share/nginx/html/data
vol_claim="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}' 2>/dev/null || true)"
mount_paths="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[*].mountPath}' 2>/dev/null || true)"
has_claim=0
for vc in $vol_claim; do
  [[ "$vc" == "portal-data" ]] && has_claim=1
done
has_mount=0
for mp in $mount_paths; do
  [[ "${mp%/}" == "/usr/share/nginx/html/data" ]] && has_mount=1
done

if [[ "$has_claim" -eq 1 && "$has_mount" -eq 1 ]]; then
  pass "Deployment '${NS}/portal' mounts PVC 'portal-data' at '/usr/share/nginx/html/data' (expected: claim 'portal-data' mounted at '/usr/share/nginx/html/data')"
else
  fail "Deployment '${NS}/portal' volumes='${vol_claim:-none}', mountPaths='${mount_paths:-none}' (expected: claim 'portal-data' mounted at '/usr/share/nginx/html/data')"
fi

# 6. Service 'portal' exists (ClusterIP, port 80) and has 3 ready endpoints
svc_type="$(kubectl -n "$NS" get svc portal -o jsonpath='{.spec.type}' 2>/dev/null || true)"
svc_port="$(kubectl -n "$NS" get svc portal -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)"
ep_ips="$(kubectl -n "$NS" get endpoints portal -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
ep_count="$(printf '%s\n' "$ep_ips" | awk '{print NF}')"
if [[ "$svc_type" == "ClusterIP" && "$svc_port" == "80" && "${ep_count:-0}" -eq 3 ]]; then
  pass "Service '${NS}/portal' has type=${svc_type}, port=${svc_port}, and ${ep_count} ready endpoints (expected: ClusterIP, 80, 3 endpoints)"
else
  fail "Service '${NS}/portal' has type=${svc_type:-missing}, port=${svc_port:-missing}, endpoints=${ep_count:-0} (expected: ClusterIP, 80, 3 endpoints)"
fi

# 7. Ingress 'portal-ingress' exists with host portal.lab.local, path / -> portal:80
ing_host="$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
ing_svc="$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || true)"
ing_port_num="$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || true)"
ing_port_name="$(kubectl -n "$NS" get ingress portal-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.name}' 2>/dev/null || true)"
if [[ "$ing_host" == "portal.lab.local" && "$ing_svc" == "portal" && ( "$ing_port_num" == "80" || -n "$ing_port_name" ) ]]; then
  pass "Ingress '${NS}/portal-ingress' routes host '${ing_host}' to '${ing_svc}:${ing_port_num:-$ing_port_name}' (expected: portal.lab.local -> portal:80)"
else
  fail "Ingress '${NS}/portal-ingress' has host='${ing_host:-missing}', backend='${ing_svc:-missing}:${ing_port_num:-${ing_port_name:-missing}}' (expected: portal.lab.local -> portal:80)"
fi

# 8. HTTP probe: curl -s -H 'Host: portal.lab.local' http://localhost:30081/ returns 200
root_code=""
root_body=""
for _ in $(seq 1 5); do
  root_code="$(curl -s -o /tmp/lab12-root.out -w '%{http_code}' --max-time 5 -H 'Host: portal.lab.local' http://localhost:30081/ 2>/dev/null || true)"
  root_body="$(cat /tmp/lab12-root.out 2>/dev/null || true)"
  [[ "$root_code" == "200" ]] && break
  sleep 2
done
rm -f /tmp/lab12-root.out

if [[ "$root_code" == "200" ]] && printf '%s\n' "$root_body" | grep -qi "nginx"; then
  pass "HTTP probe 'curl -H \"Host: portal.lab.local\" http://localhost:30081/' returned HTTP ${root_code} (expected: 200)"
else
  fail "HTTP probe 'curl -H \"Host: portal.lab.local\" http://localhost:30081/' returned HTTP ${root_code:-000} (expected: 200)"
fi

# 9. HTTP probe: curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt returns expected token
proof_code=""
proof_body=""
for _ in $(seq 1 5); do
  proof_code="$(curl -s -o /tmp/lab12-proof.out -w '%{http_code}' --max-time 5 -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt 2>/dev/null || true)"
  proof_body="$(cat /tmp/lab12-proof.out 2>/dev/null | tr -d '\r\n' || true)"
  [[ "$proof_code" == "200" && -n "$proof_body" ]] && break
  sleep 2
done
rm -f /tmp/lab12-proof.out

# Verify that proof.txt served over HTTP is non-empty and matches the file inside the mounted PVC
if [[ "$proof_code" == "200" && -n "$proof_body" ]] && ! printf '%s\n' "$proof_body" | grep -qi "<html"; then
  pass "HTTP probe 'curl -H \"Host: portal.lab.local\" http://localhost:30081/data/proof.txt' returned HTTP ${proof_code} with token '${proof_body}' (expected: HTTP 200 with PVC file content)"
else
  fail "HTTP probe 'curl -H \"Host: portal.lab.local\" http://localhost:30081/data/proof.txt' returned HTTP ${proof_code:-000} with body '${proof_body:-empty}' (expected: HTTP 200 with PVC file content)"
fi

if [[ "$passed" -eq "$total" ]]; then
  printf 'RESULT: PASS (%d/%d)\n' "$passed" "$total"
  exit 0
else
  printf 'RESULT: FAIL (%d/%d)\n' "$passed" "$total"
  exit 1
fi
