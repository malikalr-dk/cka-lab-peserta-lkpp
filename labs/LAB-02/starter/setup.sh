#!/usr/bin/env bash
# LAB-02 starter: ensure /root/lab directory exists and remove any stale report file.
set -uo pipefail

mkdir -p /root/lab
rm -f /root/lab/lab02-report.txt
printf 'READY: /root/lab initialized for LAB-02\n'
