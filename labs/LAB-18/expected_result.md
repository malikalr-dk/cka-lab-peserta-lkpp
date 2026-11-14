# Expected Result — LAB-18

State akhir yang dinilai oleh `verify/verify.sh` di node *control plane* (`cka-p3-cp`):

1. **Manifest Static Pod Bersih dari Flag Rusak:**
   - Tidak ada berkas di dalam `/etc/kubernetes/manifests/` yang masih memuat flag tidak valid `lab18-broken-flag`.

2. **Kontainer `kube-apiserver` Berjalan di Container Runtime (`crictl`):**
   - Perintah `crictl ps` pada node *control plane* menampilkan kontainer `kube-apiserver` dalam keadaan berjalan (`Running`).

3. **Komponen Control Plane di `kube-system` Berstatus `Running`:**
   - API server merespons perintah `kubectl`, dan Pod *static* `kube-apiserver`, `kube-scheduler`, serta `kube-controller-manager` di namespace `kube-system` seluruhnya berstatus `Running`.

4. **Seluruh Node Berstatus `Ready`:**
   - Seluruh node di dalam kluster (`control-plane` dan semua `worker`) berstatus `Ready`.

5. **Service `kubelet` Aktif di Seluruh Worker Node:**
   - Pemeriksaan `systemctl is-active kubelet` pada setiap worker node mengembalikan status `active`.

6. **Konfigurasi `cgroupDriver` Worker Kembali ke `systemd`:**
   - Berkas `/var/lib/kubelet/config.yaml` pada worker node yang terdampak kembali menggunakan `cgroupDriver: systemd` (sehingga perbaikan tetap bertahan saat `kubelet` di-*restart*).

7. **Output Verifier:**
   - Menjalankan `verify/verify.sh` mencetak 6 baris `PASS:` dan diakhiri dengan `RESULT: PASS (6/6)` serta kode keluar `0`.
