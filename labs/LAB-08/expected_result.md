# Expected Result — LAB-08

State akhir yang dinilai `verify/verify.sh` di node `cka-pN-cp`:

1. **Pod `config-demo` (ConfigMap & Secret) di `cka-lab08`:**
   - Pod `config-demo` berstatus `Running`.
   - Exec di container `config-demo` menampilkan env `GREETING` = `halo-cka`.
   - File `/etc/app/app.properties` ada di container `config-demo` dan memuat `mode=production` (tidak kosong).
   - Env `PASSWORD` di container `config-demo` = `s3cr3t` (sesuai `Secret` `app-secret`).

2. **Penjadwalan dengan `nodeSelector` (`sched-demo`):**
   - Node `cka-pN-w1` punya label `disk=fast`.
   - Pod `sched-demo` di `cka-lab08` `Running` dengan `spec.nodeName` = `cka-pN-w1`.

3. **Penjadwalan dengan Taint & Toleration (`taint-demo`):**
   - Node `cka-pN-w2` punya taint `dedicated=lab:NoSchedule`.
   - Pod `taint-demo` di `cka-lab08` `Running` dengan `spec.nodeName` = `cka-pN-w2`.

4. **Output Verifier:**
   - `verify/verify.sh` mencetak 7 baris `PASS:` lalu `RESULT: PASS (7/7)` dan exit code `0`.