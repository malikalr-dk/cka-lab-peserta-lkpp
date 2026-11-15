#!/usr/bin/env bash
# LAB-07 reset: undo any active later revision on Deployment web and re-apply starter state cleanly.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="gisp-app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
STARTER_YAML="${SCRIPT_DIR}/../starter/deployment.yaml"

if kubectl -n "$NS" get deployment web >/dev/null 2>&1; then
  cur_img="$(kubectl -n "$NS" get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
  if [[ -n "$cur_img" && "$cur_img" != "nginx:1.27-alpine" && "$cur_img" != "docker.io/library/nginx:1.27-alpine" ]]; then
    kubectl -n "$NS" rollout undo deployment/web >/dev/null 2>&1 || true
  fi
fi

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null 2>&1 || true

if [[ -f "$STARTER_YAML" ]]; then
  kubectl apply -f "$STARTER_YAML" >/dev/null
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
printf 'Reset complete: Deployment web in namespace %s restored to starter state\n' "$NS"
exit 0
