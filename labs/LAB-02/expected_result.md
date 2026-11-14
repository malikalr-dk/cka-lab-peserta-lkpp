# Expected Result — LAB-02

`verify/verify.sh` menilai state akhir di node `cka-pN-cp`:

1. **Status node kluster:**
   - `kubectl get nodes` menampilkan 3 node berstatus `Ready` (`cka-pN-cp`, `cka-pN-w1`, `cka-pN-w2`).

2. **Komponen `kube-system` berjalan:**
   - Pod untuk `etcd`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `coredns`, dan `calico-node` di namespace `kube-system` berstatus `Running`.

3. **File laporan `/root/lab/lab02-report.txt`:**
   - File `/root/lab/lab02-report.txt` tersedia di `cka-pN-cp`.
   - Isi file memuat keempat nama komponen control-plane:
     - `etcd`
     - `kube-apiserver`
     - `kube-controller-manager`
     - `kube-scheduler`
   - Isi file memuat alamat endpoint API server kluster (`https://<cp-ip>:6443`).

4. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 13 baris `PASS:` dan diakhiri dengan `RESULT: PASS (13/13)` serta kode keluar `0`.