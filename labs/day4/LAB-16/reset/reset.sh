#!/usr/bin/env bash
# LAB-16 reset: kembali ke state awal (Deployment 0 replika, Ingress port 8080, laporan dihapus).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
STARTER="${SCRIPT_DIR}/../starter/setup.sh"
if [[ ! -f "$STARTER" ]]; then
  STARTER="/opt/lab/labs/LAB-16/starter/setup.sh"
fi
if [[ ! -f "$STARTER" ]]; then
  printf 'FAIL: starter LAB-16 tidak ditemukan (%s)\n' "$STARTER" >&2
  exit 1
fi

bash "$STARTER" || {
  printf 'FAIL: reset LAB-16 gagal; jalankan starter secara manual\n' >&2
  exit 1
}

printf 'READY: LAB-16 kembali ke state awal (Deployment 0 replika, Ingress port 8080)\n'
