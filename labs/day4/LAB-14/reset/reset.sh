#!/usr/bin/env bash
# LAB-14 reset: hapus rilis lab17-web + namespace gisp-app, lalu jalankan starter
# (chart lokal ditulis ulang, monitoring dibiarkan hidup agar sesi berikutnya cepat).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
STARTER="${SCRIPT_DIR}/../starter/setup.sh"
if [[ ! -f "$STARTER" ]]; then
  STARTER="/opt/lab/labs/LAB-14/starter/setup.sh"
fi
if [[ ! -f "$STARTER" ]]; then
  printf 'FAIL: starter LAB-14 tidak ditemukan (%s)\n' "$STARTER" >&2
  exit 1
fi

helm uninstall lab17-web -n gisp-app --ignore-not-found >/dev/null 2>&1 || true
rm -f /root/lab17/report.txt
bash "$STARTER" || {
  printf 'FAIL: reset LAB-14 gagal; jalankan starter secara manual\n' >&2
  exit 1
}
printf 'READY: LAB-14 kembali ke state awal (chart ditulis ulang, rilis dihapus, monitoring tetap jalan)\n'
