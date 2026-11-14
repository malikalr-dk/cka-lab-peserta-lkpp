# Expected Result — LAB-08

State akhir yang dinilai oleh `verify/verify.sh` di node `cka-pN-cp`:

1. **Pod `config-demo` (ConfigMap & Secret) di `cka-lab08`:**
   - Pod `config-demo` berstatus `Running`.
   - Eksekusi di dalam container `config-demo` mencetak variabel lingkungan `GREETING` dengan nilai `halo-cka`.
   - File `/etc/app/app.properties` ada di dalam container `config-demo` dan memuat token konfigurasi (`mode=production` / tidak kosong).
   - Variabel lingkungan `PASSWORD` di dalam container `config-demo` bernilai `s3cr3t` (sesuai nilai pada Secret `app-secret`).

2. **Penjadwalan dengan `nodeSelector` (`sched-demo`):**
   - Node `cka-pN-w1` memiliki label `disk=fast`.
   - Pod `sched-demo` di `cka-lab08` berstatus `Running` dan terjadwal di `spec.nodeName` = `cka-pN-w1`.

3. **Penjadwalan dengan Taint & Toleration (`taint-demo`):**
   - Node `cka-pN-w2` memiliki taint `dedicated=lab:NoSchedule`.
   - Pod `taint-demo` di `cka-lab08` berstatus `Running` dan terjadwal di `spec.nodeName` = `cka-pN-w2`.

4. **Output Verifier:**
   - Menjalankan `verify/verify.sh` mencetak 7 baris `PASS:` dan diakhiri dengan `RESULT: PASS (7/7)` serta kode keluar `0`.
