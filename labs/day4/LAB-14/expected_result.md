# Expected Result — LAB-14

1. **Rilis Helm berakhir sehat:**
   - `helm -n gisp-app status lab17-web` → `STATUS: deployed`, `REVISION` minimal `2`.

2. **Deployment hasil Helm 2 replika:**
   - `kubectl -n gisp-app get deploy lab17-web` → `READY 2/2`.

3. **Monitoring hidup:**
   - `helm -n lab-monitoring status kube-prometheus` → `STATUS: deployed`.
   - `kubectl -n lab-monitoring get statefulset prometheus-kube-prometheus-prometheus` → satu replika siap.
   - `kubectl -n lab-monitoring get deploy kube-prometheus-grafana` → satu replika siap.

4. **Laporan terisi:**
   - `/root/lab17/report.txt` memuat `helm_revision=<n>` yang sama dengan revisi hidup, dan `prometheus_ready=yes`.

5. **Output verifier:**
   - `bash verify/verify.sh` mencetak enam baris `PASS:` dan diakhiri `RESULT: PASS (6/6)` dengan exit `0`.
