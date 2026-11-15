#!/usr/bin/env bash
# LAB-09 starter: namespace gisp-app + Deployment demo (app=demo) + client pod busybox:1.37.
# Idempotent: safe to re-run, never deletes the namespace (a re-run must not wipe the
# participant's Service work) and never pulls an image (imagePullPolicy: IfNotPresent).
# Default application image is podinfo:6.7.1 on port 9898 with /healthz. A bring-your-own-image
# class overrides it through /root/lab/lab09-image.txt (image=/port=/path=).
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="gisp-app"
DECL="/root/lab/lab09-image.txt"
DEF_IMAGE="docker.io/stefanprodan/podinfo:6.7.1"
DEF_PORT="9898"
DEF_PATH="/healthz"
CLIENT_IMAGE="busybox:1.37"
CLIENT_POD="client"
DEPLOY="demo"

IMAGE="$DEF_IMAGE"
PORT="$DEF_PORT"
HEALTH_PATH="$DEF_PATH"

if [[ -f "$DECL" ]]; then
  d_image="$(sed -n 's/^[[:space:]]*image=//p' "$DECL" | tail -1 | tr -d '[:space:]')"
  d_port="$(sed -n 's/^[[:space:]]*port=//p' "$DECL" | tail -1 | tr -d '[:space:]')"
  d_path="$(sed -n 's/^[[:space:]]*path=//p' "$DECL" | tail -1 | tr -d '[:space:]')"
  [[ -n "$d_image" ]] && IMAGE="$d_image"
  [[ -n "$d_port" ]] && PORT="$d_port"
  [[ -n "$d_path" ]] && HEALTH_PATH="$d_path"
  printf 'INFO: %s terbaca (image=%s port=%s path=%s)\n' "$DECL" "$IMAGE" "$PORT" "$HEALTH_PATH"
fi

# A path without a leading slash makes an invalid probe URL, so normalise it here.
[[ "$HEALTH_PATH" == /* ]] || HEALTH_PATH="/${HEALTH_PATH}"

# A pinned tag is mandatory: 'latest' would let the kubelet try the registry on every start, and
# the node cannot reach one.
last_seg="${IMAGE##*/}"
tag="latest"
[[ "$last_seg" == *:* ]] && tag="${last_seg##*:}"
if [[ -z "$tag" || "$tag" == "latest" ]]; then
  printf 'FAIL: image "%s" tidak memakai tag ter-pin (tag=%s). Pakai referensi seperti %s:1.0\n' \
    "$IMAGE" "${tag:-<kosong>}" "${IMAGE%:*}" >&2
  exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  printf 'FAIL: port "%s" bukan nomor port yang valid (1-65535)\n' "$PORT" >&2
  exit 1
fi

# ---- namespace -------------------------------------------------------------------------------
kubectl get namespace "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS" >/dev/null || {
  printf 'FAIL: namespace %s tidak bisa dibuat (kubectl create namespace gagal)\n' "$NS" >&2
  exit 1
}

# ---- image cache check (informational; the node pulls on first pod create) --------------------
image_repo() {
  local ref="$1" last="${1##*/}"
  if [[ "$last" == *:* ]]; then printf '%s\n' "${ref%:*}"; else printf '%s\n' "$ref"; fi
}

image_tag() {
  local last="${1##*/}"
  if [[ "$last" == *:* ]]; then printf '%s\n' "${last##*:}"; else printf 'latest\n'; fi
}

check_image_cached() {
  local ref="$1" repo tag listing first cand found=0
  local cands=()
  repo="$(image_repo "$ref")"
  tag="$(image_tag "$ref")"
  if ! command -v crictl >/dev/null 2>&1; then
    printf 'WARN: crictl tidak tersedia di node ini; cek cache image %s dilewati\n' "$ref" >&2
    return 0
  fi
  listing="$(crictl images 2>/dev/null || true)"
  if [[ -z "$listing" ]]; then
    printf 'WARN: "crictl images" tidak mengembalikan data; cek cache image %s dilewati\n' "$ref" >&2
    return 0
  fi
  # containerd may store a short reference as docker.io[/library]/<name>; accept both spellings.
  cands=("$repo")
  first="${repo%%/*}"
  case "$repo" in
    */*/*) : ;;
    */*) [[ "$first" == *.* || "$first" == *:* ]] || cands+=("docker.io/$repo") ;;
    *) cands+=("docker.io/library/$repo") ;;
  esac
  for cand in "${cands[@]}"; do
    if printf '%s\n' "$listing" | grep -F -- "$cand" | grep -qw -- "$tag"; then
      found=1
      break
    fi
  done
  if (( found == 1 )); then
    printf 'INFO: image %s ada di cache containerd node %s\n' "$ref" "$(hostname -s 2>/dev/null || hostname)"
    return 0
  fi
  printf 'WARN: image %s belum ada di cache node %s; node akan menariknya saat pod dibuat\n' \
    "$ref" "$(hostname -s 2>/dev/null || hostname)" >&2
  printf '      Kalau referensinya tidak bisa dijangkau dari node, pod akan berakhir ImagePullBackOff.\n' >&2
  return 0
}

check_image_cached "$IMAGE" || true
check_image_cached "$CLIENT_IMAGE" || true

# ---- Deployment demo -------------------------------------------------------------------------
if ! cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DEPLOY}
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
              path: ${HEALTH_PATH}
              port: ${PORT}
            initialDelaySeconds: 3
            periodSeconds: 5
EOF
then
  printf 'FAIL: Deployment %s/%s tidak bisa di-apply\n' "$NS" "$DEPLOY" >&2
  exit 1
fi

# ---- client pod (DNS/HTTP probes; recreated only when absent) --------------------------------
if ! kubectl -n "$NS" get pod "$CLIENT_POD" >/dev/null 2>&1; then
  cat <<EOF | kubectl apply -f - >/dev/null || printf 'WARN: pod klien %s/%s gagal dibuat\n' "$NS" "$CLIENT_POD" >&2
apiVersion: v1
kind: Pod
metadata:
  name: ${CLIENT_POD}
  namespace: ${NS}
  labels:
    role: client
spec:
  containers:
    - name: busybox
      image: ${CLIENT_IMAGE}
      imagePullPolicy: IfNotPresent
      command: ["sh", "-c", "sleep 3600"]
EOF
fi

printf 'INFO: menunggu sampai 60s untuk Deployment %s/%s siap...\n' "$NS" "$DEPLOY"
kubectl -n "$NS" rollout status "deployment/${DEPLOY}" --timeout=60s >/dev/null 2>&1 || true
kubectl -n "$NS" wait --for=condition=Ready "pod/${CLIENT_POD}" --timeout=60s >/dev/null 2>&1 || true

ready="$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
client_phase="$(kubectl -n "$NS" get pod "$CLIENT_POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
[[ "$ready" =~ ^[0-9]+$ ]] || ready=0
if (( ready < 1 )) || [[ "$client_phase" != "Running" ]]; then
  printf 'FAIL: state awal %s belum siap (demo ready=%s, client=%s). Cek:\n' \
    "$NS" "$ready" "${client_phase:-missing}" >&2
  printf '        kubectl -n %s get pods -o wide\n        kubectl -n %s describe deployment %s\n' \
    "$NS" "$NS" "$DEPLOY" >&2
  exit 1
fi

printf 'READY: namespace %s, Deployment %s (image %s, port %s, probe %s) dan pod klien %s siap untuk LAB-09\n' \
  "$NS" "$DEPLOY" "$IMAGE" "$PORT" "$HEALTH_PATH" "$CLIENT_POD"
