# Expected Result — LAB-13

State akhir yang dinilai `verify/verify.sh` di node *control plane* (`cka-p3-cp`):

1. **Manifest static pod bersih dari flag rusak:**
   - Tidak ada berkas di dalam `/etc/kubernetes/manifests/` yang masih memuat flag tidak valid `lab18-broken-flag`.

2. **Kontainer `kube-apiserver` jalan di container runtime (`crictl`):**
   - Perintah `crictl ps` pada node *control plane* menampilkan kontainer `kube-apiserver` dalam keadaan berjalan (`Running`).

3. **Komponen control plane di `kube-system` berstatus `Running`:**
   - API server merespons perintah `kubectl`, dan Pod *static* `kube-apiserver`, `kube-scheduler`, serta `kube-controller-manager` di namespace `kube-system` seluruhnya berstatus `Running`.

4. **Seluruh node berstatus `Ready`:**
   - Seluruh node di dalam kluster (`control-plane` dan semua `worker`) berstatus `Ready`.

5. **Service `kubelet` aktif di seluruh worker node:**
   - Pemeriksaan `systemctl is-active kubelet` pada setiap worker node mengembalikan status `active`.

6. **Konfigurasi `cgroupDriver` worker kembali ke `systemd`:**
   - Berkas `/var/lib/kubelet/config.yaml` pada worker node yang terdampak kembali memakai `cgroupDriver: systemd` (perbaikan tetap setelah `kubelet` di-restart).

7. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 6 baris `PASS:` dan diakhiri dengan `RESULT: PASS (6/6)` serta kode keluar `0`.