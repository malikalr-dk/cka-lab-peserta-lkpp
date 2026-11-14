#!/usr/bin/env bash
# LAB-02 reset: delete /root/lab/lab02-report.txt
set -uo pipefail

REPORT_FILE="${REPORT_FILE:-/root/lab/lab02-report.txt}"
rm -f "$REPORT_FILE"
printf 'Removed report file: %s\n' "$REPORT_FILE"
exit 0
