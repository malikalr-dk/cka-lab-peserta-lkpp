#!/usr/bin/env bash
# LAB-15 starter: namespace cka-lab13 with Deployment demo (podinfo by default, or the
# participant's BYO image), Service demo, Deployment client (role=client), Pod intruder
# (role=intruder). Manifests are rendered here instead of living in a static file so the
# image/port/path declared in /root/lab/lab13-image.txt cannot contradict them.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab13"
DECL="/root/lab/lab13-image.txt"
DEFAULT_IMAGE="docker.io/stefanprodan/podinfo:6.7.1"
DEFAULT_PORT="9898"
DEFAULT_PATH="/healthz"

# Last occurrence of the key wins; tolerant of CRLF and padding around '='.
decl_get() {
  [[ -f "$DECL" ]] || return 1
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$DECL" |
    tail -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//'
}

IMAGE="$DEFAULT_IMAGE"
PORT="$DEFAULT_PORT"
PROBE_PATH="$DEFAULT_PATH"
SOURCE="default"
if [[ -f "$DECL" ]]; then
  SOURCE="$DECL"
  v="$(decl_get image || true)"; [[ -n "${v:-}" ]] && IMAGE="$v"
  v="$(decl_get port || true)";  [[ -n "${v:-}" ]] && PORT="$v"
  v="$(decl_get path || true)";  [[ -n "${v:-}" ]] && PROBE_PATH="$v"
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  printf 'FAIL: port=%s dari %s bukan port TCP yang sah (expected: 1..65535)\n' "$PORT" "$SOURCE" >&2
  exit 1
fi
last_seg="${IMAGE##*/}"
if [[ "$last_seg" != *:* ]]; then
  printf 'FAIL: image=%s tidak punya tag; tag wajib di-pin (expected: <image>:<tag>, bukan latest)\n' "$IMAGE" >&2
  exit 1
fi
if [[ "$last_seg" == *:latest ]]; then
  printf 'FAIL: image=%s memakai tag latest; tag wajib di-pin (expected: <image>:<tag>, bukan latest)\n' "$IMAGE" >&2
  exit 1
fi
if [[ "$PROBE_PATH" != /* ]]; then
  printf 'FAIL: path=%s dari %s harus dimulai dengan / (expected: /healthz)\n' "$PROBE_PATH" "$SOURCE" >&2
  exit 1
fi

printf 'INFO: LAB-15 source=%s image=%s port=%s path=%s\n' \
  "$SOURCE" "$IMAGE" "$PORT" "$PROBE_PATH"

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
# A terminating namespace still answers 'create' with AlreadyExists; wait until it is
# really gone or the apply below lands in a namespace that is about to disappear.
for _ in $(seq 1 60); do
  kubectl get namespace "$NS" >/dev/null 2>&1 || break
  sleep 2
done
kubectl create namespace "$NS" >/dev/null

cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo
  namespace: ${NS}
  labels:
    app: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
        - name: demo
          image: ${IMAGE}
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: ${PORT}
          readinessProbe:
            httpGet:
              path: ${PROBE_PATH}
              port: ${PORT}
            initialDelaySeconds: 1
            periodSeconds: 3
            failureThreshold: 5
---
apiVersion: v1
kind: Service
metadata:
  name: demo
  namespace: ${NS}
  labels:
    app: demo
spec:
  type: ClusterIP
  selector:
    app: demo
  ports:
    - name: http
      port: ${PORT}
      targetPort: ${PORT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: ${NS}
  labels:
    role: client
spec:
  replicas: 1
  selector:
    matchLabels:
      role: client
  template:
    metadata:
      labels:
        role: client
    spec:
      containers:
        - name: busybox
          image: busybox:1.37
          imagePullPolicy: IfNotPresent
          command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: intruder
  namespace: ${NS}
  labels:
    role: intruder
spec:
  containers:
    - name: busybox
      image: busybox:1.37
      imagePullPolicy: IfNotPresent
      command: ["sh", "-c", "sleep 3600"]
EOF

printf 'INFO: waiting up to 90s for deployment/demo (readiness probe %s on port %s)...\n' \
  "$PROBE_PATH" "$PORT"
kubectl -n "$NS" rollout status deployment/demo --timeout=90s >/dev/null 2>&1 || true
kubectl -n "$NS" rollout status deployment/client --timeout=45s >/dev/null 2>&1 || true
kubectl -n "$NS" wait --for=condition=Ready pod/intruder --timeout=45s >/dev/null 2>&1 || true

ready_demo="$(kubectl -n "$NS" get deployment demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
ready_client="$(kubectl -n "$NS" get deployment client -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
intruder_phase="$(kubectl -n "$NS" get pod intruder -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ "${ready_demo:-0}" -lt 1 || "${ready_client:-0}" -lt 1 || "${intruder_phase:-}" != "Running" ]]; then
  printf 'FAIL: starter workloads not Ready in %s (demo=%s client=%s intruder=%s) — image %s belum ada di cache node, atau aplikasi tidak menjawab %s di port %s\n' \
    "$NS" "${ready_demo:-0}" "${ready_client:-0}" "${intruder_phase:-missing}" \
    "$IMAGE" "$PROBE_PATH" "$PORT" >&2
  kubectl -n "$NS" get pods -o wide >&2 || true
  exit 1
fi
printf 'READY: namespace %s initialized (image=%s, port=%s, probe=%s) with demo, client, intruder for LAB-15\n' \
  "$NS" "$IMAGE" "$PORT" "$PROBE_PATH"
