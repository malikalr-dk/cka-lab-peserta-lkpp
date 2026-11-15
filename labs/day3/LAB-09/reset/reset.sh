#!/usr/bin/env bash
# LAB-09 reset: back to the starter state — namespace cka-lab09 recreated with only the
# Deployment demo and the client pod; every Service created during the lab is gone.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab09"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
STARTER_SETUP="${SCRIPT_DIR}/../starter/setup.sh"
# `ssh … 'bash -s' < reset.sh` (the documented remote runner) makes BASH_SOURCE /dev/stdin, so
# SCRIPT_DIR resolves to /dev and the starter would be silently skipped — reset would delete the
# namespace and leave an empty lab behind. Fall back to the synced copy on the control-plane.
if [[ ! -f "$STARTER_SETUP" ]]; then
  STARTER_SETUP="/opt/lab/labs/LAB-09/starter/setup.sh"
fi
if [[ ! -f "$STARTER_SETUP" ]]; then
  printf 'FAIL: starter/setup.sh tidak ditemukan (script_dir=%s). Jalankan reset dari folder lab.\n' \
    "${SCRIPT_DIR:-?}" >&2
  exit 1
fi

kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true

if ! bash "$STARTER_SETUP" >/dev/null; then
  printf 'FAIL: starter LAB-09 tidak selesai; namespace %s mungkin kosong. Jalankan:\n' "$NS" >&2
  printf '        bash %s\n' "$STARTER_SETUP" >&2
  exit 1
fi

printf 'Reset complete: namespace %s dibuat ulang tanpa Service; Deployment demo dan pod client siap\n' "$NS"
exit 0
