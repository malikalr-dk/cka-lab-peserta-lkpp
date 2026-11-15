#!/usr/bin/env bash
# LAB-11 reset: delete pods, PVC, and leftover PVs (pvc-* with claimRef namespace cka-lab11),
# then recreate namespace cka-lab11 cleanly.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab11"

# Delete pods and PVC in cka-lab11 first
kubectl -n "$NS" delete pod --all --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl -n "$NS" delete pvc --all --ignore-not-found --wait=false >/dev/null 2>&1 || true

# Delete namespace cka-lab11
kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true

# Delete any PVs whose name starts with pvc- and whose claimRef namespace is cka-lab11
pvs="$(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.claimRef.namespace}{"\n"}{end}' 2>/dev/null | awk '$1 ~ /^pvc-/ && $2 == "cka-lab11" {print $1}' || true)"
for pv in $pvs; do
  kubectl delete pv "$pv" --ignore-not-found >/dev/null 2>&1 || true
  printf 'Deleted PersistentVolume: %s\n' "$pv"
done

rm -f /root/lab/lab11-answer.txt

kubectl create namespace "$NS" >/dev/null 2>&1 || true
printf 'Reset complete: pods, PVC, and cka-lab11 PVs removed; namespace %s recreated\n' "$NS"
exit 0
