#!/usr/bin/env bash
# LAB-14 starter: write Kustomize base + dev/prod overlays and a local Helm chart lab17-web
# under /root/lab17/, clean up prior lab namespaces/releases, and verify the local nginx image cache.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

LAB_DIR="/root/lab17"
NS_DEV="lab17"
NS_PROD="lab17-prod"
NS_HELM="lab17-helm"
RELEASE="lab17-web"

printf 'INFO: preparing working directory %s...\n' "$LAB_DIR"
rm -rf "$LAB_DIR"
mkdir -p \
  "${LAB_DIR}/base" \
  "${LAB_DIR}/overlays/dev" \
  "${LAB_DIR}/overlays/prod" \
  "${LAB_DIR}/chart/lab17-web/templates"

cat <<'EOF' > "${LAB_DIR}/base/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - configmap.yaml
  - deployment.yaml
  - service.yaml
EOF

cat <<'EOF' > "${LAB_DIR}/base/configmap.yaml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
  labels:
    app: web
data:
  APP_ENV: "base"
  LOG_LEVEL: "info"
EOF

cat <<'EOF' > "${LAB_DIR}/base/deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 80
          envFrom:
            - configMapRef:
                name: web-config
EOF

cat <<'EOF' > "${LAB_DIR}/base/service.yaml"
apiVersion: v1
kind: Service
metadata:
  name: web
  labels:
    app: web
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 80
EOF

cat <<'EOF' > "${LAB_DIR}/overlays/dev/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: lab17
namePrefix: dev-
labels:
  - pairs:
      env: dev
    includeTemplates: true
resources:
  - ../../base
EOF

cat <<'EOF' > "${LAB_DIR}/overlays/prod/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: lab17-prod
namePrefix: prod-
labels:
  - pairs:
      env: prod
    includeTemplates: true
resources:
  - ../../base
patches:
  - path: patch-replicas-limits.yaml
EOF

cat <<'EOF' > "${LAB_DIR}/overlays/prod/patch-replicas-limits.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: nginx
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
EOF

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

printf 'INFO: uninstalling any existing Helm release %s in %s...\n' "$RELEASE" "$NS_HELM"
helm uninstall "$RELEASE" -n "$NS_HELM" --ignore-not-found >/dev/null 2>&1 || true

printf 'INFO: cleaning up namespaces %s, %s, %s if present...\n' "$NS_DEV" "$NS_PROD" "$NS_HELM"
kubectl delete namespace "$NS_DEV" "$NS_PROD" "$NS_HELM" --ignore-not-found >/dev/null 2>&1 || true

# Recreate empty target namespaces for Kustomize overlays so 'kubectl apply -k' works directly
kubectl create namespace "$NS_DEV" >/dev/null 2>&1 || true
kubectl create namespace "$NS_PROD" >/dev/null 2>&1 || true

printf 'INFO: checking local CRI image cache for nginx:1.27-alpine...\n'
if crictl images 2>/dev/null | grep -q 'nginx.*1\.27-alpine'; then
  printf 'READY: cached image nginx:1.27-alpine verified in containerd via crictl images\n'
else
  printf 'INFO: nginx:1.27-alpine not matched in local crictl output (continuing)\n'
fi

printf 'READY: Kustomize tree written to %s/{base,overlays/dev,overlays/prod}\n' "$LAB_DIR"
printf 'READY: Local Helm chart written to %s/chart/lab17-web\n' "$LAB_DIR"
printf 'READY: LAB-14 environment initialized\n'
