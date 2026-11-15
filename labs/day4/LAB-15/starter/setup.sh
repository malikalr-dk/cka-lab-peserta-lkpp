#!/usr/bin/env bash
# LAB-15 starter: build the broken end-to-end state for the integrated incident.
# Two faults are injected on purpose:
#   A. Service 'portal' selector does not match the Deployment labels -> 0 endpoints
#   B. Ingress 'portal-ingress' points at Service 'portal-svc' which does not exist
# Everything else (ConfigMap, PVC, Deployment, PVC mount, proof file) is healthy.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab15"
TRAEFIK_NS="traefik"
CHART="/opt/lab/charts/traefik-42.4.0.tgz"
LOCAL_PATH_MANIFEST="/opt/lab/manifests/local-path.yaml"
PORT=30081

# --- prerequisites (StorageClass + Traefik on NodePort 30081) --------------------------------
if ! kubectl get storageclass local-path >/dev/null 2>&1; then
  [[ -f "$LOCAL_PATH_MANIFEST" ]] && kubectl apply -f "$LOCAL_PATH_MANIFEST" >/dev/null 2>&1 || true
fi

if ! kubectl -n "$TRAEFIK_NS" get deployment traefik >/dev/null 2>&1; then
  printf 'INFO: memasang Traefik di %s (NodePort %s)...\n' "$TRAEFIK_NS" "$PORT"
  if ! helm upgrade --install traefik "$CHART" -n "$TRAEFIK_NS" --create-namespace \
    --set image.pullPolicy=IfNotPresent \
    --set service.spec.type=NodePort \
    --set ports.web.nodePort="$PORT" \
    --set providers.kubernetesIngress.enabled=true \
    --set ingressClass.enabled=true \
    --set ingressClass.isDefaultClass=true >/dev/null 2>&1; then
    printf 'FAIL: helm install Traefik gagal di %s\n' "$TRAEFIK_NS" >&2
    exit 1
  fi
  kubectl -n "$TRAEFIK_NS" rollout status deployment/traefik --timeout=90s >/dev/null 2>&1 || {
    printf 'FAIL: Traefik tidak siap di %s\n' "$TRAEFIK_NS" >&2
    exit 1
  }
fi

# --- clean slate -----------------------------------------------------------------------------
kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  kubectl get namespace "$NS" >/dev/null 2>&1 || break
  sleep 2
done
old_pvs="$(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.claimRef.namespace}{"\n"}{end}' 2>/dev/null |
  awk -v ns="$NS" '$2 == ns {print $1}' || true)"
for pv in $old_pvs; do
  kubectl delete pv "$pv" --ignore-not-found >/dev/null 2>&1 || true
done

kubectl create namespace "$NS" >/dev/null 2>&1 || {
  printf 'FAIL: tidak bisa membuat namespace %s\n' "$NS" >&2
  exit 1
}

# --- healthy parts ---------------------------------------------------------------------------
kubectl -n "$NS" create configmap app-config --from-literal=GREETING=halo-lab15 >/dev/null

cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: portal-data
  namespace: ${NS}
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal
  namespace: ${NS}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: portal-app
  template:
    metadata:
      labels:
        app: portal-app
    spec:
      initContainers:
        - name: seed
          image: busybox:1.37
          imagePullPolicy: IfNotPresent
          command:
            - sh
            - -c
            - printf 'lab15-proof' > /data/proof.txt
          volumeMounts:
            - name: data
              mountPath: /data
      containers:
        - name: portal
          image: nginx:1.27-alpine
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: app-config
          ports:
            - containerPort: 80
          volumeMounts:
            - name: data
              mountPath: /usr/share/nginx/html/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: portal-data
EOF

# --- Fault A: selector mismatch (labels are app=portal-app) ----------------------------------
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Service
metadata:
  name: portal
  namespace: ${NS}
spec:
  type: ClusterIP
  selector:
    app: portal
  ports:
    - port: 80
      targetPort: 80
EOF

# --- Fault B: Ingress backend points at a Service that does not exist ------------------------
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portal-ingress
  namespace: ${NS}
spec:
  ingressClassName: traefik
  rules:
    - host: portal.lab.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: portal-svc
                port:
                  number: 80
EOF

# --- bounded reality check: Deployment must become Ready, the two faults must stay broken -----
printf 'INFO: menunggu Deployment %s/portal siap (maks 120s)...\n' "$NS"
ready=0
for _ in $(seq 1 40); do
  ready="$(kubectl -n "$NS" get deployment portal -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "${ready:-0}" -eq 2 ]] && break
  sleep 3
done
if [[ "${ready:-0}" -ne 2 ]]; then
  printf 'FAIL: Deployment %s/portal hanya %s/2 Ready; state awal LAB-15 tidak terbentuk\n' "$NS" "${ready:-0}" >&2
  kubectl -n "$NS" get pods -o wide >&2 || true
  exit 1
fi

ep="$(kubectl -n "$NS" get endpoints portal -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
[[ -z "$ep" ]] || printf 'WARN: Service portal sudah punya endpoint (%s); Fault A tidak terpasang\n' "$ep" >&2

printf 'READY: state awal LAB-15 di namespace %s (2 fault: selector Service, backend Ingress)\n' "$NS"
printf 'INFO: akses lewat Host portal.lab.local pada NodePort %s saat ini gagal; itu bagian tugasnya.\n' "$PORT"
