# LAB-07 — Deployments: Rolling Update, Rollback, dan Self-Healing

Tujuan: mengelola siklus hidup aplikasi menggunakan `Deployment` di namespace `cka-lab07`, termasuk mengatur strategi *rolling update*, memperbarui versi image, memeriksa riwayat revisi, melakukan *rollback* ke versi sebelumnya, serta membuktikan mekanisme *self-healing* saat sebuah Pod dihapus.

## Konteks & State Awal

- Namespace `cka-lab07` telah dibuat oleh starter, berisi satu Deployment bernama `web` (dari `starter/deployment.yaml`) dengan:
  - Image: `nginx:1.27-alpine` (`imagePullPolicy: IfNotPresent`)
  - Replicas: `3`
- Image `nginx:1.27-alpine` dan `nginx:1.29-alpine` sudah tersedia di cache lokal containerd pada semua node (tidak memerlukan akses internet).

## Tugas

1. **Inspeksi State Awal:**
   - Periksa Deployment `web` beserta Pod yang berjalan di namespace `cka-lab07`.
   - Catat image awal yang digunakan (`nginx:1.27-alpine`) serta nama dan `UID` dari salah satu Pod yang sedang berjalan.

2. **Konfigurasi Strategi Rolling Update:**
   - Perbarui spesifikasi Deployment `web` di namespace `cka-lab07` agar menggunakan strategi `RollingUpdate` dengan parameter:
     - `strategy.rollingUpdate.maxUnavailable: 1`
     - `strategy.rollingUpdate.maxSurge: 1`

3. **Rolling Update Image:**
   - Perbarui image container pada Deployment `web` menjadi `nginx:1.29-alpine`.
   - Pantau proses pembaruan menggunakan `kubectl rollout status` hingga selesai.
   - Periksa riwayat revisi Deployment menggunakan `kubectl rollout history`.

4. **Rollback ke Revisi Sebelumnya:**
   - Kembalikan (*rollback*) Deployment `web` ke revisi sebelumnya menggunakan `kubectl rollout undo`.
   - Tunggu hingga *rollout* selesai dan pastikan image container yang berjalan pada Deployment `web` telah kembali menjadi `nginx:1.27-alpine`.

5. **Pembuktian Self-Healing:**
   - Hapus salah satu Pod milik Deployment `web` di namespace `cka-lab07`.
   - Amati bagaimana ReplicaSet milik Deployment `web` secara otomatis membuat Pod pengganti baru (nama dan `creationTimestamp` baru, namun memiliki *owner reference* ReplicaSet yang sama) hingga jumlah Pod kembali `3` dan semuanya berstatus `Running`.
