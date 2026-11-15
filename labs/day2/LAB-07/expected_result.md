# Expected Result — LAB-07

State akhir yang dinilai `verify/verify.sh` di node `cka-pN-cp`:

1. **Deployment `web` di Namespace `gisp-app`:**
   - `Deployment` `web` ada di `gisp-app`.
   - `spec.replicas` = `3` dan `status.readyReplicas` = `3`.
   - Strategi `rollingUpdate`: `maxUnavailable: 1`, `maxSurge: 1`.

2. **Status & Kepemilikan Pod:**
   - Ada 3 pod `Running` di `gisp-app`; semua dimiliki ReplicaSet aktif `Deployment` `web`.

3. **State Pasca-Rollback (`nginx:1.27-alpine`):**
   - Image pada `Deployment` `web` dan pod-nya: `nginx:1.27-alpine`.
   - `kubectl rollout history deployment/web -n gisp-app` punya minimal 2 revisi (`>= 2`).

4. **Bukti Self-Healing / Rekonsiliasi Pod:**
   - Ada pod `Deployment` `web` dengan `metadata.creationTimestamp` lebih baru dari `metadata.creationTimestamp` `Deployment` `web`.

5. **Output Verifier:**
   - `verify/verify.sh` mencetak 8 baris `PASS:` lalu `RESULT: PASS (8/8)` dan exit code `0`.