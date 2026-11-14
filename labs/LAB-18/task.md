# LAB-18 — Troubleshooting Kluster & Node (2 Insiden Bertahap)

Tujuan: perbaiki worker `NotReady` (Fault A) lalu apiserver crash-loop (Fault B); semua harus tetap setelah restart kubelet.

Cakupan domain CKA: Troubleshooting (30%), yaitu troubleshoot clusters/nodes (Fault A) dan cluster components (Fault B).

## Konteks & State Awal

- Kluster `cka-p3` terdiri atas 1 node *control plane* dan 2 node *worker* (Kubernetes `v1.37.2`, `kubeadm`, `containerd` 2.x, Calico CNI).
- **Kluster sudah rusak saat lab dimulai.** Trainer menyuntikkan dua insiden secara berurutan:
  1. **Insiden 1 (Fault A):** Di awal sesi. Salah satu worker node berstatus `NotReady`.
  2. **Insiden 2 (Fault B):** Trainer suntik setelah Insiden 1 selesai (atau sesuai instruksi trainer). `kube-apiserver` crash-loop sehingga perintah `kubectl` berhenti merespons.
- Dari node *control plane*, SSH ke worker memakai kunci `/root/.ssh/lab-key`:
  ```bash
  ssh -i /root/.ssh/lab-key root@<worker-private-ip>
  ```
  Alamat IP privat masing-masing worker bisa dilihat lewat `kubectl get nodes -o wide`.
- Utilitas `crictl` (`v1.37`) sudah terpasang di setiap node (`/usr/local/bin/crictl` dengan konfigurasi `/etc/crictl.yaml`).

## Batasan penting

- **DILARANG** menjalankan `kubeadm reset` atau membangun ulang kluster dari awal.
- Perbaikan harus tetap jalan setelah `systemctl restart kubelet`.
- Backup manifest di luar `/etc/kubernetes/manifests/` sebelum sunting static pod.

---

## Tugas

### Bagian 1 — Insiden 1 (Fault A): Worker Node `NotReady`

1. **Cari worker yang `NotReady`:**
   - Periksa status seluruh node menggunakan `kubectl get nodes -o wide` dan `kubectl describe node <nama-worker>`.
   - Catat nama worker node yang berstatus `NotReady` beserta alamat `INTERNAL-IP`-nya.

2. **Telusuri akar masalah di worker:**
   - Masuk ke worker yang bermasalah melalui SSH (`ssh -i /root/.ssh/lab-key root@<worker-ip>`).
   - Periksa status dan log `kubelet` menggunakan:
     - `systemctl status kubelet`
     - `journalctl -u kubelet -n 100 --no-pager`
   - Periksa konfigurasi `/var/lib/kubelet/config.yaml` dan temukan ketidaksesuaian yang bikin `kubelet` gagal atau berhenti.

3. **Perbaiki dan pastikan persisten:**
   - Kembalikan konfigurasi `cgroupDriver` pada `/var/lib/kubelet/config.yaml` agar sesuai dengan runtime `containerd` (`systemd`).
   - Muat ulang dan jalankan kembali service `kubelet` (`systemctl daemon-reload && systemctl enable --now kubelet` / `systemctl restart kubelet`).
   - Pastikan seluruh node kembali berstatus `Ready` dari node *control plane*.

---

### Bagian 2 — Insiden 2 (Fault B): `kube-apiserver` Tidak Merespons

> Minta trainer menyuntikkan **Fault B** sebelum memulai bagian ini. Peserta tidak menyuntikkan fault sendiri.

1. **Kenali kegagalan komponen control plane:**
   - Amati bahwa perintah `kubectl` gagal menghubungi API server (`The connection to the server ... was refused`).
   - Di node *control plane*, gunakan `crictl` untuk memeriksa kontainer *static pod* yang berhenti atau *crash-loop*:
     - `crictl ps -a`
     - `crictl logs <container-id>`

2. **Cek manifest static pod dan perbaiki:**
   - Periksa berkas manifest di `/etc/kubernetes/manifests/kube-apiserver.yaml`.
   - Temukan argumen/flag tidak valid yang tercantum pada spesifikasi `command` kontainer `kube-apiserver` berdasarkan pesan error dari `crictl logs`.
   - Hapus flag yang tidak valid tersebut dari `/etc/kubernetes/manifests/kube-apiserver.yaml`.

3. **Verifikasi pemulihan kluster:**
   - Tunggu hingga `kubelet` memuat ulang *static pod* `kube-apiserver` (pantau dengan `crictl ps`).
   - Pastikan `kubectl get nodes` dan `kubectl -n kube-system get pods` kembali merespons normal serta seluruh node dan komponen *control plane* berstatus sehat.