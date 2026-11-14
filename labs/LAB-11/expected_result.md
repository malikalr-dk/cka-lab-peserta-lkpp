# Expected Result — LAB-11

State akhir yang dinilai oleh `verify/verify.sh` di node `cka-pN-cp`:

1. **PersistentVolumeClaim `data`:**
   - PVC `data` tersedia di namespace `cka-lab11` dengan `storageClassName: local-path` dan berstatus `Bound`.

2. **PersistentVolume & `claimRef`:**
   - Objek `PersistentVolume` (`PV`) di balik PVC `data` tersedia di kluster dan `spec.claimRef` miliknya menunjuk ke `cka-lab11/data`.

3. **Pod `reader` & Persistensi File `/data/proof.txt`:**
   - Pod `reader` berjalan di namespace `cka-lab11` dengan me-*mount* PVC `data` di `/data`, dan isi `/data/proof.txt` di dalam Pod `reader` adalah `hello-cka`.

4. **File Jawaban `/root/lab/lab11-answer.txt`:**
   - File `/root/lab/lab11-answer.txt` ada dan mencantumkan nama PV (`pvc-...`) yang sesuai.

5. **Reclaim Policy `Retain` & Penjelasan Hasil Penghapusan PVC:**
   - `spec.persistentVolumeReclaimPolicy` pada PV bernilai `Retain`, atau `/root/lab/lab11-answer.txt` menjelaskan perilaku/status PV (`Retain` / `Released` / tidak terhapus) saat PVC dihapus.

6. **Output Verifier:**
   - Menjalankan `verify/verify.sh` mencetak 6 baris `PASS:` dan diakhiri dengan `RESULT: PASS (6/6)` serta kode keluar `0`.
