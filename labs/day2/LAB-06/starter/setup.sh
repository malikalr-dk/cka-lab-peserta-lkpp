#!/usr/bin/env bash
# LAB-06 starter: create a clean cka-lab06 namespace and remove any leftover cluster-scoped bindings for dev-sa.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab06"

# Remove any ClusterRoleBindings that reference system:serviceaccount:cka-lab06:dev-sa and their ClusterRoles
crbs="$(kubectl get clusterrolebinding -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .subjects[*]}{.namespace}/{.name}{" "}{end}{.roleRef.name}{"\n"}{end}' 2>/dev/null | awk '/cka-lab06\/dev-sa/ {print $1 ":" $NF}' || true)"
for entry in $crbs; do
  crb_name="${entry%%:*}"
  cr_name="${entry##*:}"
  kubectl delete clusterrolebinding "$crb_name" --ignore-not-found >/dev/null 2>&1 || true
  if [[ -n "$cr_name" && "$cr_name" != "cluster-admin" && "$cr_name" != "view" && "$cr_name" != "edit" && "$cr_name" != "admin" && ! "$cr_name" =~ ^system: ]]; then
    kubectl delete clusterrole "$cr_name" --ignore-not-found >/dev/null 2>&1 || true
  fi
done

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null 2>&1 || true

printf 'READY: namespace %s created for LAB-06\n' "$NS"
