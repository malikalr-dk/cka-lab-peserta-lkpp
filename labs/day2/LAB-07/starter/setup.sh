#!/usr/bin/env bash
# LAB-07 starter: create namespace gisp-app and deploy starter/deployment.yaml cleanly.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="gisp-app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null 2>&1 || true

if [[ -f "${SCRIPT_DIR}/deployment.yaml" ]]; then
  kubectl apply -f "${SCRIPT_DIR}/deployment.yaml" >/dev/null
else
  cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: gisp-app
  labels:
    app: web
spec:
  replicas: 3
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
            - containerPort: 80
EOF
fi

kubectl -n "$NS" rollout status deployment/web --timeout=45s >/dev/null 2>&1 || true
printf 'READY: namespace %s and Deployment web initialized for LAB-07\n' "$NS"
