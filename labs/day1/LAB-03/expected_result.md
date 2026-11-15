# Expected Result — LAB-03

`verify/verify.sh` menilai state akhir di node `cka-pN-cp`:

1. **File kubeconfig admin dan root:**
   - `/etc/kubernetes/admin.conf` tersedia.
   - `/root/.kube/config` tersedia dan dapat digunakan oleh `kubectl`.

2. **Kesehatan API server:**
   - `kubectl get --raw /healthz` mengembalikan `ok`.

3. **Container API server berjalan:**
   - Container `kube-apiserver` berstatus `Running` di runtime containerd (`crictl ps`).

4. **Registrasi node control-plane:**
   - `kubectl get nodes` menampilkan node `cka-pN-cp` dalam status `NotReady` atau `Ready` (`NotReady` diharapkan sebelum CNI dipasang di LAB-04).

5. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 5 baris `PASS:` dan diakhiri dengan `RESULT: PASS (5/5)` serta kode keluar `0`.