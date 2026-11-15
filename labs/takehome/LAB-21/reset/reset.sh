#!/usr/bin/env bash
# LAB-21 reset: hapus namespace overlay, direktori kerja, dan laporan; siapkan ulang tree Kustomize.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
STARTER="${SCRIPT_DIR}/../starter/setup.sh"
if [[ ! -f "$STARTER" ]]; then
  STARTER="/opt/lab/labs/LAB-21/starter/setup.sh"
fi
if [[ ! -f "$STARTER" ]]; then
  printf 'FAIL: starter LAB-21 tidak ditemukan (%s)\n' "$STARTER" >&2
  exit 1
fi

bash "$STARTER" || {
  printf 'FAIL: reset LAB-21 gagal; jalankan starter secara manual\n' >&2
  exit 1
}
rm -f /root/lab21/report.txt
printf 'READY: LAB-21 kembali ke state awal (namespace kosong, tree Kustomize ditulis ulang)\n'
