# Expected Result — LAB-04

State akhir yang dinilai oleh `verify/verify.sh` di node `cka-pN-cp`:

1. **Ketiga Node Berstatus `Ready`:**
   - `kubectl get nodes` menampilkan 3 node (`cka-pN-cp`, `cka-pN-w1`, `cka-pN-w2`) dengan status `Ready`.

2. **DaemonSet `calico-node` Siap di Semua Node:**
   - DaemonSet `calico-node` memiliki `numberReady` = `3`.

3. **Pod `coredns` Berstatus `Running`:**
   - Seluruh pod `coredns` di namespace `kube-system` berstatus `Running`.

4. **Resolusi DNS Berfungsi:**
   - Menjalankan `nslookup kubernetes.default.svc.cluster.local` di dalam pod sekali-pakai `busybox:1.37` (`kubectl run ... --restart=Never`, tunggu `Succeeded`, baca `kubectl logs`) berhasil mengembalikan alamat IP Service `kubernetes.default.svc.cluster.local`, dan pod sementara dibersihkan.

5. **Output Verifier:**
   - Menjalankan `verify/verify.sh` mencetak 4 baris `PASS:` dan diakhiri dengan `RESULT: PASS (4/4)` serta kode keluar `0`.
