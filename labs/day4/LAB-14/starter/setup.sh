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
mon_ok=0
for _ in $(seq 1 80); do
  prom="$(kubectl -n "$NS_MON" get statefulset prometheus-kube-prometheus-prometheus -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
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

printf 'READY: chart lab17-web ada di %s/chart/lab17-web\n' "$LAB_DIR"
printf 'READY: monitoring %s jalan di %s (Prometheus + Grafana)\n' "$MON_RELEASE" "$NS_MON"
printf 'READY: LAB-14 siap (Helm + monitoring)\n'
