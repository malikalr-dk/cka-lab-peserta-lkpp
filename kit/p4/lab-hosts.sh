#!/usr/bin/env bash
# lab-hosts.sh — sekali jalan: daftarkan lab04 -> 157.10.160.158 di /etc/hosts. Butuh sudo.
set -euo pipefail
IP="${LAB_IP:-157.10.160.158}"
NAME="${LAB_NAME:-lab04}"
HOSTS="${LAB_HOSTS:-/etc/hosts}"
BEGIN="# >>> CKA lab (dikelola lab-hosts.sh)"
END="# <<< CKA lab"

[ -w "$HOSTS" ] || { echo "butuh sudo: sudo bash $0"; exit 1; }
clean=$(awk -v b="$BEGIN" -v e="$END" '$0==b{f=1} $0==e{f=0;next} !f' "$HOSTS")
{ printf '%s\n' "$clean" "$BEGIN" "$IP $NAME" "$END"; } > "$HOSTS"
echo "ok: ssh root@$NAME -> $IP"
grep -qE "^[0-9.]+[[:space:]]+$NAME($|[[:space:]])" "$HOSTS" || echo "WARN: $NAME belum muncul di $HOSTS"
