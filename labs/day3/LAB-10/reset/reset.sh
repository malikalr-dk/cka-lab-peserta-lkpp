#!/usr/bin/env bash
# LAB-10 reset: delete both Ingresses in cka-lab10 and re-apply the starter manifests (including the broken Ingress).
# Leave Traefik installed in namespace 'traefik' — removing and reinstalling it would make reruns slow
# andLAB-12 also relies on Traefik on NodePort 30081.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab10"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
STARTER_YAML="${SCRIPT_DIR}/../starter/manifests.yaml"

kubectl create namespace "$NS" >/dev/null 2>&1 || true

# Delete both Ingresses so app-ingress is removed and broken-ingress is reset to its broken starter state
kubectl -n "$NS" delete ingress app-ingress broken-ingress --ignore-not-found >/dev/null 2>&1 || true

if [[ -f "$STARTER_YAML" ]]; then
  kubectl apply -f "$STARTER_YAML" >/dev/null
else
  cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: cka-lab10
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
  namespace: cka-lab10
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
  namespace: cka-lab10
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
printf 'Reset complete: app-ingress deleted, broken-ingress restored to starter state in %s (Traefik kept installed)\n' "$NS"
exit 0
