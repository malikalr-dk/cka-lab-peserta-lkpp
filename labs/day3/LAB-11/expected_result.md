# Expected Result — LAB-11

State akhir yang dinilai `verify/verify.sh` di node `cka-pN-cp`:

1. **PersistentVolumeClaim `data`:**
   - PVC `data` ada di `gisp-app` dengan `storageClassName: local-path` dan status `Bound`.

2. **PersistentVolume & `claimRef`:**
   - PV di balik PVC `data` ada di kluster; `spec.claimRef` menunjuk ke `gisp-app/data`.

3. **Pod `reader` & Persistensi File `/data/proof.txt`:**
   - Pod `reader` jalan di `gisp-app`, mount PVC `data` di `/data`; isi `/data/proof.txt` = `hello-cka`.

4. **File Jawaban `/root/lab/lab11-answer.txt`:**
   - File `/root/lab/lab11-answer.txt` ada dan mencantumkan nama PV (`pvc-...`) yang cocok.

5. **Reclaim Policy `Retain` & Penjelasan Hasil Penghapusan PVC:**
   - `spec.persistentVolumeReclaimPolicy` pada PV = `Retain`, atau `/root/lab/lab11-answer.txt` menjelaskan perilaku/status PV (`Retain` / `Released` / tidak terhapus) saat PVC dihapus.

6. **Output Verifier:**
   - `verify/verify.sh` mencetak 6 baris `PASS:` lalu `RESULT: PASS (6/6)` dan exit code `0`.