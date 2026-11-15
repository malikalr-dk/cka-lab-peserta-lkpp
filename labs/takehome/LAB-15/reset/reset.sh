#!/usr/bin/env bash
# LAB-15 reset: delete namespace cka-lab13 and recreate the starter state (Deployment demo,
# Service demo, Deployment client, Pod intruder). The BYO declaration
# /root/lab/lab13-image.txt is left untouched, so the starter re-renders the same image.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab13"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
STARTER_SETUP="${SCRIPT_DIR}/../starter/setup.sh"
# `bash -s < reset.sh` (the documented remote runner) makes BASH_SOURCE /dev/stdin,
# so SCRIPT_DIR resolves to /dev and the starter is silently skipped — reset would
# delete the namespace and leave nothing behind. Fall back to the copy on the CP.
if [[ ! -f "$STARTER_SETUP" ]]; then
  STARTER_SETUP="/opt/lab/labs/LAB-15/starter/setup.sh"
fi
if [[ ! -f "$STARTER_SETUP" ]]; then
  printf 'FAIL: starter/setup.sh tidak ditemukan (script_dir=%s). Jalankan reset dari folder lab.\n' \
    "${SCRIPT_DIR:-?}" >&2
  exit 1
fi

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true

bash "$STARTER_SETUP" || { printf 'FAIL: starter setup for %s did not complete\n' "$NS" >&2; exit 1; }

printf 'Reset complete: namespace %s recreated (Deployment demo, Service demo, client, intruder); NetworkPolicy dihapus untuk LAB-15\n' "$NS"
exit 0
