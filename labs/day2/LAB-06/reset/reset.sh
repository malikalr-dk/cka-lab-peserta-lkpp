#!/usr/bin/env bash
# LAB-06 reset: delete namespace cka-lab06 and any cluster-scoped ClusterRole/ClusterRoleBinding created for dev-sa,
# then recreate the starter namespace.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab06"

# Find and delete any ClusterRoleBinding referencing cka-lab06/dev-sa along with its non-built-in ClusterRole
crbs="$(kubectl get clusterrolebinding -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .subjects[*]}{.namespace}/{.name}{" "}{end}{.roleRef.name}{"\n"}{end}' 2>/dev/null | awk '/cka-lab06\/dev-sa/ {print $1 ":" $NF}' || true)"
for entry in $crbs; do
  crb_name="${entry%%:*}"
  cr_name="${entry##*:}"
  kubectl delete clusterrolebinding "$crb_name" --ignore-not-found >/dev/null 2>&1 || true
  printf 'Deleted ClusterRoleBinding: %s\n' "$crb_name"
  if [[ -n "$cr_name" && "$cr_name" != "cluster-admin" && "$cr_name" != "view" && "$cr_name" != "edit" && "$cr_name" != "admin" && ! "$cr_name" =~ ^system: ]]; then
    kubectl delete clusterrole "$cr_name" --ignore-not-found >/dev/null 2>&1 || true
    printf 'Deleted ClusterRole: %s\n' "$cr_name"
  fi
done

# Also remove common lab ClusterRole/ClusterRoleBinding names if created without matching subject
kubectl delete clusterrolebinding node-lister-binding dev-node-reader-binding --ignore-not-found >/dev/null 2>&1 || true
kubectl delete clusterrole node-lister dev-node-reader --ignore-not-found >/dev/null 2>&1 || true

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null 2>&1 || true
printf 'Reset complete: namespace %s recreated cleanly\n' "$NS"
exit 0
