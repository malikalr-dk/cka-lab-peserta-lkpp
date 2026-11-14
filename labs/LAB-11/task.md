# LAB-11 — Storage: StorageClass, PV/PVC, dan Reclaim Policy

Tujuan: memanfaatkan *dynamic provisioning* dari `StorageClass` `local-path` melalui `PersistentVolumeClaim` (`PVC`), membuktikan persistensi data lintas siklus hidup Pod (`writer` ke `reader`), serta mengamati perilaku `persistentVolumeReclaimPolicy: Retain`.

## Konteks & State Awal

- Skrip starter telah menyiapkan namespace `cka-lab11` dan memastikan `StorageClass` bernama `local-path` (beserta *provisioner*-nya dari `/opt/lab/manifests/local-path.yaml`) aktif di kluster.
- Perhatikan bahwa `StorageClass` `local-path` menggunakan `volumeBindingMode: WaitForFirstConsumer`, sehingga PVC baru akan berstatus `Pending` sampai ada Pod yang menggunakannya.
- Selalu gunakan `imagePullPolicy: IfNotPresent` pada setiap Pod (`busybox:1.37` atau `nginx:1.27-alpine` sudah tersedia di cache lokal).

## Tugas

1. **Buat PersistentVolumeClaim (`data`):**
   - Di dalam namespace `cka-lab11`, buat sebuah `PersistentVolumeClaim` bernama `data` dengan spesifikasi:
     - `storageClassName: local-path`
     - `accessModes`: `ReadWriteOnce`
     - `resources.requests.storage`: `1Gi`
   - Setelah Pod konsumen berjalan (lihat langkah 2), pastikan PVC `data` berstatus `Bound` dan catat nama `PersistentVolume` (`PV`, berawalan `pvc-...`) yang diprovisikan secara dinamis.

2. **Buktikan Persistensi Data (`writer` → `reader`):**
   - Buat Pod bernama `writer` di namespace `cka-lab11` yang me-*mount* PVC `data` pada path `/data`, lalu tulis tepat string `hello-cka` ke dalam file `/data/proof.txt`.
   - Setelah file ditulis, hapus Pod `writer`.
   - Buat Pod baru bernama `reader` di namespace `cka-lab11` yang me-*mount* PVC `data` yang sama pada path `/data` dan biarkan Pod `reader` tetap berjalan (`Running`).
   - Buktikan bahwa file `/data/proof.txt` di dalam Pod `reader` masih ada dan berisi `hello-cka`.

3. **Reclaim Policy (`Retain`) & Dokumentasi Jawaban:**
   - Ubah `persistentVolumeReclaimPolicy` pada objek `PersistentVolume` (`PV`) yang terikat ke PVC `data` menjadi `Retain`.
   - Anda dapat mendemonstrasikan perbedaan perilaku `Retain` dibandingkan kebijakan bawaan `Delete` ketika sebuah PVC dihapus (pada kebijakan `Retain`, menghapus PVC **tidak** menghapus objek PV melainkan mengubah statusnya menjadi `Released`). Pastikan pada akhir lab, PVC `data`, PV terkait (dengan kebijakan `Retain`), dan Pod `reader` (dengan `/data/proof.txt` berisi `hello-cka`) berada dalam keadaan aktif (`Bound` / `Running`) untuk dinilai oleh verifier.
   - Jawab pertanyaan berikut di dalam file `/root/lab/lab11-answer.txt` (satu baris untuk setiap poin):
     - **Baris 1:** Nama `PersistentVolume` (`pvc-...`) yang diprovisikan untuk PVC `data`.
     - **Baris 2:** Penjelasan singkat mengenai apa yang terjadi pada `PersistentVolume` ber-policy `Retain` apabila `PersistentVolumeClaim`-nya dihapus (status PV dan nasib datanya).
