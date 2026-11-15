#!/usr/bin/env bash
# LAB-12 starter: create empty namespace gisp-app and ensure cluster prerequisites
# (Traefik on NodePort 30081 and local-path StorageClass) are present locally.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="gisp-app"
TRAEFIK_NS="traefik"
CHART="/opt/lab/charts/traefik-42.4.0.tgz"
LOCAL_PATH_MANIFEST="/opt/lab/manifests/local-path.yaml"

# Ensure local-path StorageClass is installed
if ! kubectl get storageclass local-path >/dev/null 2>&1; then
  if [[ -f "$LOCAL_PATH_MANIFEST" ]]; then
    printf 'INFO: applying local-path provisioner from %s...\n' "$LOCAL_PATH_MANIFEST"
    kubectl apply -f "$LOCAL_PATH_MANIFEST" >/dev/null 2>&1 || true
  fi
fi
kubectl -n local-path-storage patch deployment local-path-provisioner \
  --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]' >/dev/null 2>&1 || true

# Ensure Traefik is installed on NodePort 30081 (normally already installed by LAB-10)
if ! kubectl -n "$TRAEFIK_NS" get deployment traefik >/dev/null 2>&1; then
  printf 'INFO: installing Traefik in namespace %s from %s (NodePort 30081)...\n' "$TRAEFIK_NS" "$CHART"
  if ! helm upgrade --install traefik "$CHART" \
    -n "$TRAEFIK_NS" --create-namespace \
    --set image.pullPolicy=IfNotPresent \
    --set service.spec.type=NodePort \
    --set ports.web.nodePort=30081 \
    --set providers.kubernetesIngress.enabled=true \
    --set ingressClass.enabled=true \
    --set ingressClass.isDefaultClass=true >/dev/null 2>&1; then
    printf 'FAIL: helm install Traefik gagal di %s\n' "$TRAEFIK_NS" >&2
    helm upgrade --install traefik "$CHART" -n "$TRAEFIK_NS" --create-namespace \
      --set image.pullPolicy=IfNotPresent --set service.spec.type=NodePort \
      --set ports.web.nodePort=30081 --set providers.kubernetesIngress.enabled=true \
      --set ingressClass.enabled=true --set ingressClass.isDefaultClass=true 2>&1 | tail -5 >&2
    exit 1
  fi
  printf 'INFO: waiting up to 90s for Traefik deployment in namespace %s...\n' "$TRAEFIK_NS"
  if ! kubectl -n "$TRAEFIK_NS" rollout status deployment/traefik --timeout=90s >/dev/null 2>&1; then
    printf 'FAIL: Traefik deployment tidak siap di %s\n' "$TRAEFIK_NS" >&2
    exit 1
  fi
fi

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true

# Remove any leftover PVs from prior runs bound to gisp-app
old_pvs="$(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.claimRef.namespace}{"\n"}{end}' 2>/dev/null | awk '$1 ~ /^pvc-/ && $2 == "gisp-app" {print $1}' || true)"
for pv in $old_pvs; do
  kubectl delete pv "$pv" --ignore-not-found >/dev/null 2>&1 || true
done

kubectl create namespace "$NS" >/dev/null 2>&1 || true
printf 'READY: empty namespace %s created for LAB-12\n' "$NS"
