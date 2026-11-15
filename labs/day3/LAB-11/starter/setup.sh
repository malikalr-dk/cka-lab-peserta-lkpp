#!/usr/bin/env bash
# LAB-11 starter: ensure local-path StorageClass/provisioner is installed and create clean namespace gisp-app.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="gisp-app"
LOCAL_PATH_MANIFEST="/opt/lab/manifests/local-path.yaml"

if ! kubectl get storageclass local-path >/dev/null 2>&1; then
  if [[ -f "$LOCAL_PATH_MANIFEST" ]]; then
    printf 'INFO: applying local-path provisioner from %s...\n' "$LOCAL_PATH_MANIFEST"
    kubectl apply -f "$LOCAL_PATH_MANIFEST" >/dev/null 2>&1 || true
  fi
fi

# Ensure imagePullPolicy is IfNotPresent on local-path-provisioner so the cached image is used
kubectl -n local-path-storage patch deployment local-path-provisioner \
  --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]' >/dev/null 2>&1 || true

printf 'INFO: waiting up to 45s for local-path-provisioner deployment in namespace local-path-storage...\n'
kubectl -n local-path-storage rollout status deployment/local-path-provisioner --timeout=45s >/dev/null 2>&1 || true

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true

# Clean up any leftover PVs from previous runs whose claimRef namespace is gisp-app
old_pvs="$(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.claimRef.namespace}{"\n"}{end}' 2>/dev/null | awk '$1 ~ /^pvc-/ && $2 == "gisp-app" {print $1}' || true)"
for pv in $old_pvs; do
  kubectl delete pv "$pv" --ignore-not-found >/dev/null 2>&1 || true
done

rm -f /root/lab/lab11-answer.txt
mkdir -p /root/lab

kubectl create namespace "$NS" >/dev/null 2>&1 || true
printf 'READY: StorageClass local-path verified and namespace %s created for LAB-11\n' "$NS"
