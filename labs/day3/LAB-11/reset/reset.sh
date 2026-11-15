#!/usr/bin/env bash
# LAB-11 reset: delete pods, PVC, and leftover PVs (pvc-* with claimRef namespace gisp-app),
# then recreate namespace gisp-app cleanly.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="gisp-app"

# Delete pods and PVC in gisp-app first
kubectl -n "$NS" delete pod --all --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl -n "$NS" delete pvc --all --ignore-not-found --wait=false >/dev/null 2>&1 || true

# Delete namespace gisp-app
kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true

# Delete any PVs whose name starts with pvc- and whose claimRef namespace is gisp-app
pvs="$(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.claimRef.namespace}{"\n"}{end}' 2>/dev/null | awk '$1 ~ /^pvc-/ && $2 == "gisp-app" {print $1}' || true)"
for pv in $pvs; do
  kubectl delete pv "$pv" --ignore-not-found >/dev/null 2>&1 || true
  printf 'Deleted PersistentVolume: %s\n' "$pv"
done

rm -f /root/lab/lab11-answer.txt

kubectl create namespace "$NS" >/dev/null 2>&1 || true
printf 'Reset complete: pods, PVC, and gisp-app PVs removed; namespace %s recreated\n' "$NS"
exit 0
