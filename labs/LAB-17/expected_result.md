# Expected Result — LAB-17

State akhir yang dinilai oleh `verify/verify.sh` di node `cka-pN-cp`:

1. **Kustomize Overlay `dev` (`namespace: lab17`):**
   - `Deployment` bernama `dev-web` di namespace `lab17` berstatus *Ready* dengan `spec.replicas: 1`, `status.readyReplicas: 1`, dan memiliki label `env: dev`.

2. **Kustomize Overlay `prod` (`namespace: lab17-prod`):**
   - `Deployment` bernama `prod-web` di namespace `lab17-prod` berstatus *Ready* dengan `spec.replicas: 3` dan `status.readyReplicas: 3`.

3. **Penerapan Patch Resource Limits pada `prod` vs `dev`:**
   - Kontainer pertama pada `Deployment/prod-web` memiliki `resources.limits.cpu` tidak kosong (`200m`), sedangkan `Deployment/dev-web` tidak memiliki `resources.limits.cpu`.

4. **Status dan Revisi Rilis Helm (`namespace: lab17-helm`):**
   - Perintah `helm -n lab17-helm status lab17-web` menampilkan `STATUS: deployed` dan nomor `REVISION >= 2` setelah melewati siklus `install` -> `upgrade` -> `rollback` -> `upgrade`.

5. **Jumlah Replika Deployment Helm (`lab17-web`):**
   - `Deployment/lab17-web` di namespace `lab17-helm` memiliki `spec.replicas: 2` dan `status.readyReplicas: 2` sesuai perintah `helm upgrade --set replicaCount=2` terakhir.

6. **File Laporan `/root/lab17/report.txt`:**
   - File `/root/lab17/report.txt` tersedia, memiliki kunci `kustomize_prod_replicas=<n>` dan `helm_revision=<n>` dengan nilai tidak kosong, serta nilai `kustomize_prod_replicas` sama dengan jumlah replika aktual `Deployment/prod-web` (`3`).

7. **Output Verifier:**
   - Menjalankan `verify/verify.sh` mencetak 6 baris `PASS:` dan diakhiri dengan `RESULT: PASS (6/6)` serta kode keluar `0`.
