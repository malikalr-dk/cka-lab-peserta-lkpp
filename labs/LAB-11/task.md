# LAB-11 — Storage: StorageClass, PV/PVC, dan Reclaim Policy

Tujuan: provisi PVC `local-path`, bukti data hidup `writer`→`reader`, set reclaim `Retain`. Verifier cek `Bound`, file, dan jawaban PV.

## Konteks & State Awal

- Starter sudah bikin namespace `cka-lab11` dan memastikan `StorageClass` `local-path` (provisioner dari `/opt/lab/manifests/local-path.yaml`) aktif.
- `StorageClass` `local-path` memakai `volumeBindingMode: WaitForFirstConsumer`; PVC baru `Pending` sampai ada pod yang memakainya.
- Setiap pod pakai `imagePullPolicy: IfNotPresent` (`busybox:1.37` atau `nginx:1.27-alpine` sudah di cache lokal).

## Tugas

1. **Buat PersistentVolumeClaim (`data`):**
   - Di `cka-lab11`, buat `PersistentVolumeClaim` `data` dengan:
     - `storageClassName: local-path`
     - `accessModes`: `ReadWriteOnce`
     - `resources.requests.storage`: `1Gi`
   - Setelah pod konsumen jalan (langkah 2), pastikan PVC `data` `Bound` dan catat nama `PersistentVolume` (`PV`, awalan `pvc-...`) yang ter-provisi.

2. **Buktikan persistensi data (`writer` → `reader`):**
   - Buat pod `writer` di `cka-lab11` yang mount PVC `data` ke `/data`, lalu tulis string `hello-cka` ke `/data/proof.txt`.
   - Setelah file tertulis, hapus pod `writer`.
   - Buat pod `reader` di `cka-lab11` yang mount PVC `data` yang sama ke `/data`; biarkan `Running`.
   - Buktikan `/data/proof.txt` di dalam `reader` masih ada dan berisi `hello-cka`.

3. **Reclaim policy (`Retain`) & jawaban dokumentasi:**
   - Ubah `persistentVolumeReclaimPolicy` pada PV yang terikat PVC `data` menjadi `Retain`.
   - Bandingkan perilaku `Retain` dengan default `Delete` saat PVC dihapus (dengan `Retain`, hapus PVC **tidak** hapus PV, hanya ubah status jadi `Released`). Di akhir lab, biarkan PVC `data`, PV terkait (`Retain`), dan pod `reader` (`/data/proof.txt` berisi `hello-cka`) tetap `Bound` / `Running` untuk verifier.
   - Jawab di `/root/lab/lab11-answer.txt` (satu baris per poin):
     - **Baris 1:** Nama `PersistentVolume` (`pvc-...`) untuk PVC `data`.
     - **Baris 2:** Singkat: apa yang terjadi pada PV ber-policy `Retain` kalau PVC-nya dihapus (status PV dan nasib data).