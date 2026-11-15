#!/usr/bin/env bash
# LAB-21 starter (take-home): write a Kustomize base plus dev/prod overlays under /root/lab21/,
# then create the two target namespaces empty so 'kubectl apply -k' works directly.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

LAB_DIR="/root/lab21"
NS_DEV="lab21"
NS_PROD="lab21-prod"

printf 'INFO: menyiapkan %s...\n' "$LAB_DIR"
rm -rf "$LAB_DIR"
mkdir -p "${LAB_DIR}/base" "${LAB_DIR}/overlays/dev" "${LAB_DIR}/overlays/prod"

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
namespace: lab21
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
namespace: lab21-prod
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
            limits:
              cpu: 200m
EOF

kubectl delete namespace "$NS_DEV" "$NS_PROD" --ignore-not-found >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  kubectl get namespace "$NS_DEV" >/dev/null 2>&1 || break
  sleep 2
done
kubectl create namespace "$NS_DEV" >/dev/null 2>&1 || true
kubectl create namespace "$NS_PROD" >/dev/null 2>&1 || true

printf 'READY: Kustomize tree siap di %s (base, overlays/dev, overlays/prod)\n' "$LAB_DIR"
printf 'INFO: namespace %s dan %s kosong dan siap dipakai.\n' "$NS_DEV" "$NS_PROD"
