#!/usr/bin/env bash
# LAB-14 starter: write the local Helm chart lab17-web under /root/lab17/,
# clean up the Helm namespace, and install kube-prometheus-stack from the local chart
# into lab-monitoring so the monitoring part needs no internet.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

LAB_DIR="/root/lab17"
NS_HELM="gisp-app"
NS_MON="lab-monitoring"
RELEASE="lab17-web"
MON_RELEASE="kube-prometheus"
MON_CHART="/opt/lab/charts/kube-prometheus-stack-93.3.0.tgz"

printf 'INFO: menyiapkan %s/chart/lab17-web...\n' "$LAB_DIR"
rm -rf "$LAB_DIR"
mkdir -p "${LAB_DIR}/chart/lab17-web/templates"

cat <<'EOF' > "${LAB_DIR}/chart/lab17-web/Chart.yaml"
apiVersion: v2
name: lab17-web
description: Minimal local NGINX Helm chart for CKA LAB-14
type: application
version: 0.1.0
appVersion: "1.27-alpine"
EOF

cat <<'EOF' > "${LAB_DIR}/chart/lab17-web/values.yaml"
replicaCount: 1

image:
  repository: nginx
  tag: "1.27-alpine"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
EOF

cat <<'EOF' > "${LAB_DIR}/chart/lab17-web/templates/deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: {{ .Chart.Name }}
    app.kubernetes.io/instance: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Chart.Name }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Chart.Name }}
        app.kubernetes.io/instance: {{ .Release.Name }}
    spec:
      containers:
        - name: nginx
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
EOF

cat <<'EOF' > "${LAB_DIR}/chart/lab17-web/templates/service.yaml"
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: {{ .Chart.Name }}
    app.kubernetes.io/instance: {{ .Release.Name }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app.kubernetes.io/name: {{ .Chart.Name }}
    app.kubernetes.io/instance: {{ .Release.Name }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
EOF

printf 'INFO: membersihkan rilis dan namespace %s...\n' "$NS_HELM"
helm uninstall "$RELEASE" -n "$NS_HELM" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete namespace "$NS_HELM" --ignore-not-found >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  kubectl get namespace "$NS_HELM" >/dev/null 2>&1 || break
  sleep 2
done
kubectl create namespace "$NS_HELM" >/dev/null 2>&1 || true

# --- monitoring: pasang dari chart lokal, tanpa internet -------------------------------------
if [[ ! -f "$MON_CHART" ]]; then
  printf 'FAIL: chart monitoring tidak ada: %s\n' "$MON_CHART" >&2
  exit 1
fi

printf 'INFO: memasang kube-prometheus-stack di %s dari %s (maks 8 menit)...\n' "$NS_MON" "$MON_CHART"
if ! helm upgrade --install "$MON_RELEASE" "$MON_CHART" -n "$NS_MON" --create-namespace \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.retention=2h \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set grafana.resources.requests.memory=128Mi >/tmp/lab14-monitoring.log 2>&1; then
  printf 'FAIL: helm install kube-prometheus-stack gagal (lihat /tmp/lab14-monitoring.log)\n' >&2
  tail -5 /tmp/lab14-monitoring.log >&2 || true
  exit 1
fi

printf 'INFO: menunggu Prometheus dan Grafana siap...\n'
# Nama StatefulSet dicari lewat label: chart memotong nama default menjadi
# `prometheus-kube-prometheus-kube-prome-prometheus`, jadi nama hardcode tidak pernah cocok dan
# loop ini akan selalu menunggu penuh 8 menit lalu gagal walau monitoring sudah siap.
prom_sts="$(kubectl -n "$NS_MON" get statefulset -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
[[ -n "$prom_sts" ]] || prom_sts="prometheus-${MON_RELEASE}-prometheus"
mon_ok=0
for _ in $(seq 1 80); do
  prom="$(kubectl -n "$NS_MON" get statefulset "$prom_sts" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  graf="$(kubectl -n "$NS_MON" get deployment "$MON_RELEASE-grafana" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  if [[ "${prom:-0}" -ge 1 && "${graf:-0}" -ge 1 ]]; then
    mon_ok=1
    break
  fi
  sleep 6
done
if [[ "$mon_ok" -ne 1 ]]; then
  printf 'FAIL: monitoring belum siap (prometheus=%s grafana=%s). Cek: kubectl -n %s get pods\n' \
    "${prom:-0}" "${graf:-0}" "$NS_MON" >&2
  exit 1
fi

# --- metrics-server: prasyarat langkah `kubectl top` di task.md ------------------------------
# Image sudah ada di cache containerd setiap node; kalau metrics API sudah menjawab, jangan
# disentuh supaya starter tetap cepat saat dijalankan berulang.
METRICS_MANIFEST="/opt/lab/manifests/metrics-server.yaml"
if kubectl top nodes >/dev/null 2>&1; then
  printf 'INFO: metrics API sudah menjawab; metrics-server tidak disentuh\n'
elif [[ -f "$METRICS_MANIFEST" ]]; then
  printf 'INFO: memasang metrics-server dari %s\n' "$METRICS_MANIFEST"
  if ! kubectl apply -f "$METRICS_MANIFEST" >/dev/null; then
    printf 'WARN: kubectl apply %s gagal; metrics API bisa tetap tidak tersedia\n' "$METRICS_MANIFEST" >&2
  fi
  existing_args="$(kubectl -n kube-system get deployment metrics-server -o jsonpath='{.spec.template.spec.containers[0].args[*]}' 2>/dev/null || true)"
  if ! printf '%s\n' "$existing_args" | grep -q -- '--kubelet-insecure-tls'; then
    kubectl -n kube-system patch deployment metrics-server --type='json' \
      -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null 2>&1 || true
  fi
  kubectl -n kube-system patch deployment metrics-server --type='json' \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]' >/dev/null 2>&1 || true
  kubectl -n kube-system rollout status deployment/metrics-server --timeout=60s >/dev/null 2>&1 || true
  for _ in $(seq 1 30); do
    kubectl top nodes >/dev/null 2>&1 && break
    sleep 2
  done
  if kubectl top nodes >/dev/null 2>&1; then
    printf 'INFO: metrics API menjawab (kubectl top nodes OK)\n'
  else
    printf 'WARN: metrics API belum menjawab; langkah `kubectl top` bisa gagal. Cek: kubectl -n kube-system get pods -l k8s-app=metrics-server\n' >&2
  fi
else
  printf 'WARN: %s tidak ada dan metrics API belum menjawab; langkah `kubectl top` dilewati\n' "$METRICS_MANIFEST" >&2
fi

printf 'READY: chart lab17-web ada di %s/chart/lab17-web\n' "$LAB_DIR"
printf 'READY: monitoring %s jalan di %s (Prometheus + Grafana)\n' "$MON_RELEASE" "$NS_MON"
printf 'READY: LAB-14 siap (Helm + monitoring)\n'
