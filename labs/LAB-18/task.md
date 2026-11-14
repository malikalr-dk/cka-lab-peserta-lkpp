# LAB-18 — Troubleshooting Kluster & Node (2 Insiden Bertahap)

Tujuan: mendiagnosis dan memperbaiki **dua insiden kerusakan kluster** (*trainer-injected faults*) pada domain **Troubleshooting (30%)** CKA — mencakup *troubleshoot clusters and nodes* (Fault A pada worker node) dan *troubleshoot cluster components* (Fault B pada control-plane static pod).

## Konteks & State Awal

- Kluster `cka-p3` terdiri atas 1 node *control plane* dan 2 node *worker* (Kubernetes `v1.37.2`, `kubeadm`, `containerd` 2.x, Calico CNI).
- **Kluster sudah dalam kondisi rusak saat lab dimulai.** Trainer menyuntikkan dua insiden secara berurutan:
  1. **Insiden 1 (Fault A — Worker Node Troubleshooting):** Disuntikkan di awal sesi. Salah satu worker node berstatus `NotReady`.
  2. **Insiden 2 (Fault B — Control Plane Component Troubleshooting):** Disuntikkan oleh trainer setelah Anda menyelesaikan Insiden 1 (atau sesuai instruksi trainer). `kube-apiserver` mengalami *crash-loop* sehingga perintah `kubectl` berhenti merespons.
- Dari node *control plane*, Anda dapat melakukan SSH ke worker node menggunakan kunci `/root/.ssh/lab-key`:
  ```bash
  ssh -i /root/.ssh/lab-key root@<worker-private-ip>
  ```
  Alamat IP privat masing-masing worker dapat dilihat melalui `kubectl get nodes -o wide`.
- Utilitas `crictl` (`v1.37`) telah terpasang di setiap node (`/usr/local/bin/crictl` dengan konfigurasi `/etc/crictl.yaml`).

## Batasan Penting (Constraints)

- **DILARANG menjalankan `kubeadm reset`** atau membangun ulang kluster dari awal.
- Seluruh perbaikan **wajib bersifat persisten** meskipun service `kubelet` di-*restart* (`systemctl restart kubelet`).
- Selalu buat salinan cadangan (*backup*) di luar direktori `/etc/kubernetes/manifests/` sebelum menyunting manifest *static pod*.

---

## Tugas

### Bagian 1 — Insiden 1 (Fault A): Worker Node `NotReady`

1. **Identifikasi Node yang Bermasalah:**
   - Periksa status seluruh node menggunakan `kubectl get nodes -o wide` dan `kubectl describe node <nama-worker>`.
   - Catat nama worker node yang berstatus `NotReady` beserta alamat `INTERNAL-IP`-nya.

2. **Temukan Akar Masalah (*Root Cause*) di Worker Node:**
   - Masuk ke worker node yang bermasalah melalui SSH (`ssh -i /root/.ssh/lab-key root@<worker-ip>`).
   - Periksa status dan log `kubelet` menggunakan:
     - `systemctl status kubelet`
     - `journalctl -u kubelet -n 100 --no-pager`
   - Periksa konfigurasi `/var/lib/kubelet/config.yaml` dan temukan ketidaksesuaian konfigurasi yang menyebabkan `kubelet` gagal berjalan / dihentikan.

3. **Perbaiki secara Persisten:**
   - Kembalikan konfigurasi `cgroupDriver` pada `/var/lib/kubelet/config.yaml` agar sesuai dengan runtime `containerd` (`systemd`).
   - Muat ulang dan jalankan kembali service `kubelet` (`systemctl daemon-reload && systemctl enable --now kubelet` / `systemctl restart kubelet`).
   - Pastikan seluruh node kembali berstatus `Ready` dari node *control plane*.

---

### Bagian 2 — Insiden 2 (Fault B): `kube-apiserver` Tidak Merespons

> Minta trainer menyuntikkan **Fault B** sebelum memulai bagian ini. Peserta tidak menyuntikkan fault sendiri.

1. **Identifikasi Kegagalan Komponen Control Plane:**
   - Amati bahwa perintah `kubectl` gagal menghubungi API server (`The connection to the server ... was refused`).
   - Di node *control plane*, gunakan `crictl` untuk memeriksa kontainer *static pod* yang berhenti atau *crash-loop*:
     - `crictl ps -a`
     - `crictl logs <container-id>`

2. **Periksa Manifest Static Pod & Perbaiki:**
   - Periksa berkas manifest di `/etc/kubernetes/manifests/kube-apiserver.yaml`.
   - Temukan argumen/flag tidak valid yang tercantum pada spesifikasi `command` kontainer `kube-apiserver` berdasarkan pesan error dari `crictl logs`.
   - Hapus flag yang tidak valid tersebut dari `/etc/kubernetes/manifests/kube-apiserver.yaml`.

3. **Verifikasi Pemulihan Kluster:**
   - Tunggu hingga `kubelet` memuat ulang *static pod* `kube-apiserver` (pantau dengan `crictl ps`).
   - Pastikan `kubectl get nodes` dan `kubectl -n kube-system get pods` kembali merespons normal serta seluruh node dan komponen *control plane* berstatus sehat.
