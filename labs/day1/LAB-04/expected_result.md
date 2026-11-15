# Expected Result — LAB-04

`verify/verify.sh` menilai state akhir di node `cka-pN-cp`:

1. **Ketiga node berstatus `Ready`:**
   - `kubectl get nodes` menampilkan 3 node (`cka-pN-cp`, `cka-pN-w1`, `cka-pN-w2`) dengan status `Ready`.

2. **DaemonSet `calico-node` siap di semua node:**
   - DaemonSet `calico-node` memiliki `numberReady` = `3`.

3. **Pod `coredns` berstatus `Running`:**
   - Seluruh pod `coredns` di namespace `kube-system` berstatus `Running`.

4. **Resolusi DNS berfungsi:**
   - Menjalankan `nslookup kubernetes.default.svc.cluster.local` di dalam pod sekali-pakai `busybox:1.37` (`kubectl run ... --restart=Never`, tunggu `Succeeded`, baca `kubectl logs`) berhasil mengembalikan alamat IP Service `kubernetes.default.svc.cluster.local`, dan pod sementara dibersihkan.

5. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 4 baris `PASS:` dan diakhiri dengan `RESULT: PASS (4/4)` serta kode keluar `0`.