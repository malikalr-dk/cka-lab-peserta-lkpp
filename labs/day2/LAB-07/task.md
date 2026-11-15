# LAB-07 — Deployments: Rolling Update, Rollback, dan Self-Healing

Tujuan: kelola `Deployment` `web` di `cka-lab07` (rolling update, rollback, self-healing). Bukti: strategi, image, revisi, dan pod pengganti.

## Konteks & State Awal

- Starter sudah bikin namespace `cka-lab07` dengan satu `Deployment` `web` (dari `starter/deployment.yaml`):
  - Image: `nginx:1.27-alpine` (`imagePullPolicy: IfNotPresent`)
  - Replicas: `3`
- Image `nginx:1.27-alpine` dan `nginx:1.29-alpine` sudah ada di cache `containerd` semua node (tanpa internet).

## Tugas

1. **Periksa state awal:**
   - Cek `Deployment` `web` dan pod yang jalan di `cka-lab07`.
   - Catat image awal (`nginx:1.27-alpine`) plus nama dan `UID` satu pod yang aktif.

2. **Set strategi rolling update:**
   - Perbarui spesifikasi `Deployment` `web` di `cka-lab07` agar memakai strategi `RollingUpdate` dengan:
     - `strategy.rollingUpdate.maxUnavailable: 1`
     - `strategy.rollingUpdate.maxSurge: 1`

3. **Rolling update image:**
   - Ubah image container `Deployment` `web` ke `nginx:1.29-alpine`.
   - Pantau dengan `kubectl rollout status` sampai selesai.
   - Lihat riwayat dengan `kubectl rollout history`.

4. **Rollback ke revisi sebelumnya:**
   - Rollback `Deployment` `web` dengan `kubectl rollout undo`.
   - Tunggu rollout selesai; pastikan image di `Deployment` `web` kembali `nginx:1.27-alpine`.

5. **Buktikan self-healing:**
   - Hapus satu pod milik `Deployment` `web` di `cka-lab07`.
   - Amati ReplicaSet `web` bikin pod pengganti (nama dan `creationTimestamp` baru, *owner reference* ReplicaSet sama) sampai ada `3` pod `Running`.