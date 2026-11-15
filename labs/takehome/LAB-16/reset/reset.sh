#!/usr/bin/env bash
# LAB-16 reset: delete namespace cka-lab14 and restore the starter state (Deployment/Service
# demo, honouring /root/lab/lab14-image.txt if present). metrics-server stays in kube-system.
# Re-running the starter is deliberate: the Deployment image comes from the BYO declaration, so
# a second copy of that render here would drift from the one the participant actually got.
# setup.sh already deletes the namespace and waits for termination; its exit status is ours.
set -uo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG=/root/.kube/config
fi

NS="cka-lab14"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
SETUP="${SCRIPT_DIR}/../starter/setup.sh"
# `bash -s < reset.sh` (the documented remote runner) makes BASH_SOURCE /dev/stdin, so
# SCRIPT_DIR resolves to /dev and the setup below would be silently skipped. Fall back to
# the copy on the CP.
if [[ ! -f "$SETUP" ]]; then
  SETUP="/opt/lab/labs/LAB-16/starter/setup.sh"
fi
if [[ ! -f "$SETUP" ]]; then
  printf 'FAIL: starter/setup.sh tidak ditemukan (script_dir=%s). Jalankan reset dari folder lab.\n' \
    "${SCRIPT_DIR:-?}" >&2
  exit 1
fi

if ! bash "$SETUP"; then
  printf 'FAIL: starter/setup.sh failed; namespace %s is not in the starter state\n' "$NS" >&2
  exit 1
fi

printf 'Reset complete: namespace %s recreated with Deployment/Service demo (metrics-server kept in kube-system)\n' "$NS"
exit 0
