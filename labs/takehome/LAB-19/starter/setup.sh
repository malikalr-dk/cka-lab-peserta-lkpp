#!/usr/bin/env bash
# LAB-19 starter: apply Gateway API CRDs (/opt/lab/manifests/gateway-api.yaml),
# install/upgrade Traefik from /opt/lab/charts/traefik-42.4.0.tgz with Gateway API provider enabled,
# and create namespace cka-lab19 with Deployment web, Service web, and a broken HTTPRoute (broken-route).
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab19"
TRAEFIK_NS="traefik"
GW_MANIFEST="/opt/lab/manifests/gateway-api.yaml"
CHART="/opt/lab/charts/traefik-42.4.0.tgz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

if [[ -f "$GW_MANIFEST" ]]; then
  printf 'INFO: applying Gateway API CRDs from %s...\n' "$GW_MANIFEST"
  kubectl apply -f "$GW_MANIFEST" >/dev/null 2>&1 || true
fi

printf 'INFO: waiting up to 30s for Gateway API CRDs to be Established...\n'
crd_ok=0
for _ in $(seq 1 15); do
  crd_ok=1
  for crd in gatewayclasses gateways httproutes; do
    crd_cond="$(kubectl get crd "${crd}.gateway.networking.k8s.io" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}' 2>/dev/null || true)"
    [[ "$crd_cond" == *"Established=True"* ]] || crd_ok=0
  done
  [[ "$crd_ok" -eq 1 ]] && break
  crd_ok=0
  sleep 2
done
if [[ "$crd_ok" -ne 1 ]]; then
  printf 'FAIL: Gateway API CRDs (gatewayclasses, gateways, httproutes) not Established=True after 30s — source %s\n' "$GW_MANIFEST" >&2
  exit 1
fi

printf 'INFO: installing/updating Traefik with Gateway API provider enabled in namespace %s...\n' "$TRAEFIK_NS"
# A NodePort Service has no loadbalancer.status, so statusAddress.service alone leaves Gateway
# status.addresses empty and the participant's "wait for an address" step never completes.
# Advertise the node IP the NodePort is reachable on instead.
NODE_IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)"
GW_STATUS_ARGS=()
[[ -n "$NODE_IP" ]] && GW_STATUS_ARGS=(--set "providers.kubernetesGateway.statusAddress.ip=${NODE_IP}")

HELM_LOG="$(mktemp)"
if ! helm upgrade --install traefik "$CHART" \
  -n "$TRAEFIK_NS" --create-namespace \
  --set image.pullPolicy=IfNotPresent \
  --set service.spec.type=NodePort \
  --set ports.web.nodePort=30081 \
  --set ports.web.port=80 \
  --set ports.web.exposedPort=80 \
  --set providers.kubernetesIngress.enabled=true \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true \
  --set providers.kubernetesGateway.enabled=true \
  --set providers.kubernetesGateway.statusAddress.service.enabled=true \
  ${GW_STATUS_ARGS[@]+"${GW_STATUS_ARGS[@]}"} \
  --set gateway.enabled=false \
  --set gatewayClass.enabled=true >"$HELM_LOG" 2>&1; then
  printf 'FAIL: helm upgrade Traefik gagal (chart %s) — keluaran helm:\n' "$CHART" >&2
  tail -20 "$HELM_LOG" >&2
  rm -f "$HELM_LOG"
  exit 1
fi
rm -f "$HELM_LOG"

# Ensure Traefik ClusterRole grants read/status access to gateway.networking.k8s.io in case chart defaults omit a verb
cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1 || true
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: traefik-gateway-api-extra
rules:
  - apiGroups: ["gateway.networking.k8s.io"]
    resources: ["gatewayclasses", "gateways", "httproutes", "referencegrants", "tcproutes", "tlsroutes", "grpcroutes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["gateway.networking.k8s.io"]
    resources: ["gatewayclasses/status", "gateways/status", "httproutes/status", "tcproutes/status", "tlsroutes/status", "grpcroutes/status"]
    verbs: ["update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: traefik-gateway-api-extra
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-gateway-api-extra
subjects:
  - kind: ServiceAccount
    name: traefik
    namespace: traefik
EOF

# Ensure GatewayClass 'traefik' exists so participants can bind a Gateway with gatewayClassName: traefik
if ! kubectl get gatewayclass traefik >/dev/null 2>&1; then
  cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1 || true
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: traefik
spec:
  controllerName: traefik.io/gateway-controller
EOF
fi

printf 'INFO: waiting up to 120s for Traefik deployment in namespace %s...\n' "$TRAEFIK_NS"
if ! kubectl -n "$TRAEFIK_NS" rollout status deployment/traefik --timeout=120s >/dev/null 2>&1; then
  printf 'FAIL: Deployment %s/traefik not ready after 120s — the Gateway API provider cannot program Gateways\n' "$TRAEFIK_NS" >&2
  kubectl -n "$TRAEFIK_NS" get pods >&2 || true
  exit 1
fi

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
# A terminating namespace still answers 'create' with AlreadyExists; wait until it is gone or the
# apply below lands in a namespace that is about to disappear (starter state lost, READY printed).
for _ in $(seq 1 60); do
  kubectl get namespace "$NS" >/dev/null 2>&1 || break
  sleep 2
done
kubectl create namespace "$NS" >/dev/null

if [[ -f "${SCRIPT_DIR}/manifests.yaml" ]]; then
  if ! kubectl apply -f "${SCRIPT_DIR}/manifests.yaml" >/dev/null; then
    printf 'FAIL: kubectl apply %s/manifests.yaml gagal — namespace %s tidak berada di state awal\n' "$SCRIPT_DIR" "$NS" >&2
    exit 1
  fi
else
  cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: cka-lab19
  labels:
    app: web
spec:
  replicas: 2
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
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: cka-lab19
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
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: broken-route
  namespace: cka-lab19
spec:
  parentRefs:
    - name: web-gateway
  hostnames:
    - "broken.gw.local"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: web
          port: 8080
EOF
fi

printf 'INFO: waiting up to 90s for Deployment %s/web rollout...\n' "$NS"
if ! kubectl -n "$NS" rollout status deployment/web --timeout=90s >/dev/null 2>&1; then
  printf 'FAIL: Deployment %s/web not ready after 90s (image nginx:1.27-alpine, replicas 2)\n' "$NS" >&2
  kubectl -n "$NS" get pods >&2 || true
  exit 1
fi
printf 'READY: Gateway API CRDs, Traefik Gateway provider, and namespace %s initialized for LAB-19\n' "$NS"
