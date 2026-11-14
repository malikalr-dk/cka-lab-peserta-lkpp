#!/usr/bin/env bash
# LAB-14 starter: install metrics-server from /opt/lab/manifests/metrics-server.yaml with
# --kubelet-insecure-tls, wait for pod metrics, then create namespace cka-lab14 with
# Deployment demo (podinfo by default, requests.cpu=100m) and Service demo on the same port.
# Never pulls: the images must already be in the node CRI cache, and the preflight below says
# so instead of letting the participant meet ImagePullBackOff.
#
# Bring-your-own image: if /root/lab/lab14-image.txt exists it is honoured here, so the
# Deployment the participant sees is already their own application. Format:
#   image=<registry>/<name>:<tag>
#   port=<port>
#   path=<endpoint that burns CPU under load>
# Defaults: docker.io/stefanprodan/podinfo:6.7.1 / 9898 / /
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab14"
METRICS_MANIFEST="/opt/lab/manifests/metrics-server.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
DECL="/root/lab/lab14-image.txt"

DEF_IMAGE="docker.io/stefanprodan/podinfo:6.7.1"
DEF_PORT="9898"
DEF_PATH="/"

IMAGE="$DEF_IMAGE"
PORT="$DEF_PORT"
APP_PATH="$DEF_PATH"

trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

if [[ -f "$DECL" ]]; then
  printf 'INFO: reading BYO declaration %s\n' "$DECL"
  while IFS='=' read -r key value || [[ -n "${key:-}" ]]; do
    key="$(trim "${key:-}")"
    value="$(trim "${value:-}")"
    case "$key" in
      image) [[ -n "$value" ]] && IMAGE="$value" ;;
      port)  [[ -n "$value" ]] && PORT="$value" ;;
      path)  [[ -n "$value" ]] && APP_PATH="$value" ;;
      ""|\#*) : ;;
      *) printf 'WARN: unknown key in %s ignored: %s\n' "$DECL" "$key" >&2 ;;
    esac
  done < "$DECL"
fi

# Tag must be pinned: an unpinned or :latest image breaks the "no pull mid-class" rule and
# makes the Deployment non-reproducible between participants.
case "$IMAGE" in
  *:latest)
    printf 'FAIL: image %s uses the :latest tag (expected: <registry>/<name>:<tag> with a pinned version, e.g. :1.2.3)\n' "$IMAGE" >&2
    exit 1
    ;;
esac
if [[ "${IMAGE##*/}" != *:* ]]; then
  printf 'FAIL: image %s has no tag (expected: <registry>/<name>:<tag> in %s)\n' "$IMAGE" "$DECL" >&2
  exit 1
fi
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -lt 1 ]] || [[ "$PORT" -gt 65535 ]]; then
  printf 'FAIL: port=%s in %s is not a valid port (expected: 1-65535)\n' "$PORT" "$DECL" >&2
  exit 1
fi
[[ "$APP_PATH" == /* ]] || APP_PATH="/$APP_PATH"

# --- image cache preflight (read-only, never pulls) ---------------------------------------
# The node has no registry access during class, so an image that is not already in the CRI
# cache becomes ImagePullBackOff in front of the participant. `crictl images` is a read-only
# listing and this starter is trainer-side; the participant path stays pure kubectl.
if command -v crictl >/dev/null 2>&1; then
  cri_images="$(crictl images 2>/dev/null || true)"
  img_in_cache() {
    local ref="$1" name tag
    name="${ref##*/}"
    case "$name" in
      *:*) tag="${name##*:}"; name="${name%%:*}" ;;
      *)   tag="latest" ;;
    esac
    printf '%s\n' "$cri_images" \
      | awk -v n="$name" -v t="$tag" 'index($1, n) > 0 && $2 == t { found = 1 } END { exit !found }'
  }
  for ref in "$IMAGE" "busybox:1.37"; do
    if img_in_cache "$ref"; then
      printf 'INFO: image present in node cache: %s\n' "$ref"
      continue
    fi
    if [[ "$ref" == "busybox:1.37" || "$IMAGE" == "$DEF_IMAGE" ]]; then
      printf 'FAIL: image %s is not in the node CRI cache (expected: imported by the trainer the day before class, see docs/lab-images.md; this starter never pulls)\n' "$ref" >&2
      exit 1
    fi
    printf 'WARN: BYO image %s not matched in the node CRI cache (expected: imported by the trainer; continuing because the cache name may differ from the declared ref)\n' "$ref" >&2
  done
else
  printf 'WARN: crictl not found; skipping the image cache preflight\n' >&2
fi

# --- metrics-server (prerequisite of the whole lab) -------------------------------------
if [[ -f "$METRICS_MANIFEST" ]]; then
  printf 'INFO: applying metrics-server from %s...\n' "$METRICS_MANIFEST"
  if ! kubectl apply -f "$METRICS_MANIFEST" >/dev/null; then
    printf 'WARN: kubectl apply %s failed; metrics API may stay unavailable\n' "$METRICS_MANIFEST" >&2
  fi
else
  printf 'WARN: %s not found; assuming metrics-server is already installed\n' "$METRICS_MANIFEST" >&2
fi

# Patch metrics-server deployment for kubeadm self-signed kubelet certs and the local containerd cache
existing_args="$(kubectl -n kube-system get deployment metrics-server -o jsonpath='{.spec.template.spec.containers[0].args[*]}' 2>/dev/null || true)"
if ! printf '%s\n' "$existing_args" | grep -q -- '--kubelet-insecure-tls'; then
  kubectl -n kube-system patch deployment metrics-server --type='json' \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null 2>&1 || true
fi
kubectl -n kube-system patch deployment metrics-server --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]' >/dev/null 2>&1 || true

printf 'INFO: waiting up to 60s for deployment kube-system/metrics-server rollout...\n'
if ! kubectl -n kube-system rollout status deployment/metrics-server --timeout=60s; then
  printf 'FAIL: deployment kube-system/metrics-server did not become ready\n' >&2
  exit 1
fi

printf 'INFO: waiting up to 120s for metrics API (kubectl top nodes) to answer...\n'
metrics_ready=0
for attempt in $(seq 1 60); do
  if kubectl top nodes >/dev/null 2>&1; then
    metrics_ready=1
    break
  fi
  printf 'INFO: node metrics pending (%d/60)\n' "$attempt"
  sleep 2
done
if [[ "$metrics_ready" -ne 1 ]]; then
  printf 'FAIL: metrics API did not return node metrics within 120s\n' >&2
  exit 1
fi

# --- namespace + demo workload ----------------------------------------------------------
kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
printf 'INFO: waiting up to 120s for namespace %s deletion...\n' "$NS"
for attempt in $(seq 1 60); do
  if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
    break
  fi
  printf 'INFO: namespace deletion pending (%d/60)\n' "$attempt"
  sleep 2
done
if kubectl get namespace "$NS" >/dev/null 2>&1; then
  printf 'FAIL: namespace %s still exists after 120s\n' "$NS" >&2
  exit 1
fi
if ! kubectl create namespace "$NS" >/dev/null; then
  printf 'FAIL: could not create namespace %s\n' "$NS" >&2
  exit 1
fi

# The manifest is rendered rather than shipped as a file because the image and port come from
# the participant's declaration. It is left on disk so the trainer can diff what was applied.
RENDER_DIR="/root/lab"
mkdir -p "$RENDER_DIR" 2>/dev/null || RENDER_DIR="/tmp"
RENDERED="${RENDER_DIR}/lab14-manifests.yaml"

cat > "$RENDERED" <<EOF
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
          resources:
            requests:
              cpu: 100m
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
EOF

printf 'INFO: applying %s (image=%s port=%s path=%s)\n' "$RENDERED" "$IMAGE" "$PORT" "$APP_PATH"
if ! kubectl apply -f "$RENDERED" >/dev/null; then
  printf 'FAIL: could not apply %s\n' "$RENDERED" >&2
  exit 1
fi

printf 'INFO: waiting up to 120s for Deployment %s/demo rollout...\n' "$NS"
if ! kubectl -n "$NS" rollout status deployment/demo --timeout=120s; then
  printf 'FAIL: Deployment %s/demo did not become ready\n' "$NS" >&2
  kubectl -n "$NS" get pods -o wide 2>/dev/null || true
  printf 'HINT: ImagePullBackOff means the image is not in the node cache yet — the trainer imports it the day before class (lab-images.md).\n' >&2
  exit 1
fi

# kubectl top nodes answers as soon as the node metrics land, but pod metrics lag by one
# metric-resolution window (~60s on a cold metrics-server). The task's first step is
# `kubectl -n <ns> top pods`, so wait for that too instead of letting the student hit
# "error: metrics not available yet" on a freshly started cluster.
printf 'INFO: waiting up to 180s for pod metrics in %s (kubectl -n %s top pods)...\n' "$NS" "$NS"
top_pods=""
for attempt in $(seq 1 90); do
  top_pods="$(kubectl -n "$NS" top pods --no-headers 2>/dev/null || true)"
  if [[ -n "$top_pods" ]]; then
    break
  fi
  printf 'INFO: pod metrics pending (%d/90)\n' "$attempt"
  sleep 2
done
if [[ -z "$top_pods" ]]; then
  printf 'FAIL: pod metrics in %s still unavailable after 180s\n' "$NS" >&2
  exit 1
fi

printf 'READY: metrics-server verified, namespace %s initialized (Deployment/Service demo, image=%s port=%s path=%s)\n' \
  "$NS" "$IMAGE" "$PORT" "$APP_PATH"
