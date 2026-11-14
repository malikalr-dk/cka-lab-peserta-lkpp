# Expected Result — LAB-07

State akhir yang dinilai oleh `verify/verify.sh` di node `cka-pN-cp`:

1. **Deployment `web` di Namespace `cka-lab07`:**
   - Deployment `web` tersedia di namespace `cka-lab07`.
   - `spec.replicas` bernilai `3` dan `status.readyReplicas` bernilai `3`.
   - Strategi `rollingUpdate` memiliki `maxUnavailable: 1` dan `maxSurge: 1`.

2. **Status & Kepemilikan Pod:**
   - Terdapat 3 Pod aktif yang berstatus `Running` di `cka-lab07` dan semuanya dimiliki (*owned*) oleh ReplicaSet aktif milik Deployment `web`.

3. **State Pasca-Rollback (`nginx:1.27-alpine`):**
   - Image container yang berjalan pada Deployment `web` dan Pod-nya adalah `nginx:1.27-alpine`.
   - Riwayat `kubectl rollout history deployment/web -n cka-lab07` memiliki sedikitnya 2 revisi (`>= 2`).

4. **Bukti Self-Healing / Rekonsiliasi Pod:**
   - Terdapat Pod milik Deployment `web` yang memiliki `metadata.creationTimestamp` lebih baru daripada `metadata.creationTimestamp` Deployment `web`.

5. **Output Verifier:**
   - Menjalankan `verify/verify.sh` mencetak 8 baris `PASS:` dan diakhiri dengan `RESULT: PASS (8/8)` serta kode keluar `0`.
