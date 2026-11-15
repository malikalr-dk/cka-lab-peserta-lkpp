#!/usr/bin/env bash
# LAB-15 reset: kembalikan ke state awal (dua fault terpasang lagi).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
STARTER="${SCRIPT_DIR}/../starter/setup.sh"
if [[ ! -f "$STARTER" ]]; then
  STARTER="/opt/lab/labs/LAB-15/starter/setup.sh"
fi
if [[ ! -f "$STARTER" ]]; then
  printf 'FAIL: starter LAB-15 tidak ditemukan (%s)\n' "$STARTER" >&2
  exit 1
fi

bash "$STARTER" || {
  printf 'FAIL: reset LAB-15 gagal; jalankan starter secara manual\n' >&2
  exit 1
}

printf 'READY: LAB-15 kembali ke state awal (Fault A selector, Fault B backend Ingress)\n'
