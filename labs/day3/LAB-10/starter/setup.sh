#!/usr/bin/env bash
# LAB-10 starter: install Traefik from the local chart on NodePort 30081 (if not already configured)
# and create namespace gisp-app with Deployment app, Service app, and broken-ingress.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="gisp-app"
TRAEFIK_NS="traefik"
CHART="/opt/lab/charts/traefik-42.4.0.tgz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

printf 'INFO: installing/updating Traefik release in namespace %s from %s (NodePort 30081)...\n' "$TRAEFIK_NS" "$CHART"
if ! helm upgrade --install traefik "$CHART" \
  -n "$TRAEFIK_NS" --create-namespace \
  --set image.pullPolicy=IfNotPresent \
  --set service.spec.type=NodePort \
  --set ports.web.nodePort=30081 \
  --set providers.kubernetesIngress.enabled=true \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true >/dev/null 2>&1; then
  printf 'FAIL: helm install Traefik gagal — jalankan tanpa >/dev/null untuk melihat error chart\n' >&2
  helm upgrade --install traefik "$CHART" -n "$TRAEFIK_NS" --create-namespace \
    --set image.pullPolicy=IfNotPresent --set service.spec.type=NodePort \
    --set ports.web.nodePort=30081 --set providers.kubernetesIngress.enabled=true \
    --set ingressClass.enabled=true --set ingressClass.isDefaultClass=true 2>&1 | tail -5 >&2
  exit 1
fi

printf 'INFO: waiting up to 90s for Traefik deployment in namespace %s...\n' "$TRAEFIK_NS"
if ! kubectl -n "$TRAEFIK_NS" rollout status deployment/traefik --timeout=90s >/dev/null 2>&1; then
  printf 'FAIL: Traefik deployment tidak siap (namespace %s) — cek kubectl -n %s get pods\n' "$TRAEFIK_NS" "$TRAEFIK_NS" >&2
  exit 1
fi

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null 2>&1 || true

if [[ -f "${SCRIPT_DIR}/manifests.yaml" ]]; then
  kubectl apply -f "${SCRIPT_DIR}/manifests.yaml" >/dev/null
else
  cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: gisp-app
  labels:
    app: app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app
  namespace: gisp-app
  labels:
    app: app
spec:
  type: ClusterIP
  selector:
    app: app
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: broken-ingress
  namespace: gisp-app
spec:
  ingressClassName: traefik
  rules:
    - host: broken.lab.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-svc-typo
                port:
                  number: 80
EOF
fi

printf 'INFO: waiting up to 45s for Deployment %s/app rollout...\n' "$NS"
kubectl -n "$NS" rollout status deployment/app --timeout=45s >/dev/null 2>&1 || true
printf 'READY: Traefik (NodePort 30081) and namespace %s initialized for LAB-10\n' "$NS"
