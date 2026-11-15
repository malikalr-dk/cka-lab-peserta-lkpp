#!/usr/bin/env bash
# LAB-16 starter: final recovery assessment state.
# Two faults are injected on purpose:
#   A. Deployment 'portal' is scaled to 0 replicas
#   B. Ingress 'portal-ingress' sends traffic to port 8080 instead of 80
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab16"
TRAEFIK_NS="traefik"
CHART="/opt/lab/charts/traefik-42.4.0.tgz"
LOCAL_PATH_MANIFEST="/opt/lab/manifests/local-path.yaml"
PORT=30081
REPORT="/root/lab/lab16-report.txt"

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
mkdir -p "$(dirname "$REPORT")"
rm -f "$REPORT"

kubectl -n "$NS" create configmap app-config --from-literal=GREETING=halo-lab16 >/dev/null

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
  replicas: 0
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
            - printf 'lab16-proof' > /data/proof.txt
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
---
apiVersion: v1
kind: Service
metadata:
  name: portal
  namespace: ${NS}
spec:
  type: ClusterIP
  selector:
    app: portal-app
  ports:
    - port: 80
      targetPort: 80
---
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
                name: portal
                port:
                  number: 8080
EOF

printf 'INFO: menunggu PVC %s/portal-data Bound (maks 120s)...\n' "$NS"
phase=""
for _ in $(seq 1 40); do
  phase="$(kubectl -n "$NS" get pvc portal-data -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  [[ "$phase" == "Bound" ]] && break
  sleep 3
done
if [[ "$phase" != "Bound" ]]; then
  printf 'FAIL: PVC %s/portal-data tidak Bound (status=%s)\n' "$NS" "${phase:-missing}" >&2
  exit 1
fi

printf 'READY: state awal LAB-16 di namespace %s (Deployment 0 replika, Ingress port 8080)\n' "$NS"
printf 'INFO: tulis laporan di %s setelah layanan pulih.\n' "$REPORT"
