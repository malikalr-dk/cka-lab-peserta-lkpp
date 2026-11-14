# Expected Result — LAB-03

State akhir yang dinilai oleh `verify/verify.sh` di node `cka-pN-cp`:

1. **File Kubeconfig Admin & Root:**
   - `/etc/kubernetes/admin.conf` tersedia.
   - `/root/.kube/config` tersedia dan dapat digunakan oleh `kubectl`.

2. **Kesehatan API Server:**
   - `kubectl get --raw /healthz` mengembalikan `ok`.

3. **Container API Server Berjalan:**
   - Container `kube-apiserver` berstatus `Running` di runtime containerd (`crictl ps`).

4. **Registrasi Node Control-Plane:**
   - `kubectl get nodes` menampilkan node `cka-pN-cp` dalam status `NotReady` atau `Ready` (`NotReady` diharapkan sebelum CNI dipasang di LAB-04).

5. **Output Verifier:**
   - Menjalankan `verify/verify.sh` mencetak 5 baris `PASS:` dan diakhiri dengan `RESULT: PASS (5/5)` serta kode keluar `0`.
