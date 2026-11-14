# Expected Result — LAB-01

State akhir yang dinilai oleh `verify/verify.sh` di node `cka-pN-cp`:

1. **Namespace `lab01`:**
   - Namespace `lab01` ada di kluster dan memiliki fase `Active`.

2. **Pod Imperatif `web` (`nginx:1.27-alpine`):**
   - Pod `web` di namespace `lab01` berstatus `Running` (kontainer siap) dan menjalankan image `nginx:1.27-alpine`.

3. **Pod Deklaratif `web2` (`nginx:1.29-alpine`):**
   - Pod `web2` di namespace `lab01` berstatus `Running` (kontainer siap) dan menjalankan image `nginx:1.29-alpine`.

4. **Manifest Hasil Generate Client-Side (`/root/lab/lab01-pod.yaml`):**
   - File `/root/lab/lab01-pod.yaml` ada di disk, merepresentasikan objek `Pod/web2`, dan perintah `kubectl -n lab01 apply --dry-run=server -f /root/lab/lab01-pod.yaml` selesai dengan kode keluar `0`.

5. **Bukti Layanan HTTP & Versi `nginx` di Dalam `web2`:**
   - Eksekusi `kubectl -n lab01 exec web2 -- wget -qO- http://127.0.0.1/` dan `kubectl -n lab01 exec web2 -- nginx -v` berhasil dan melaporkan versi `1.29.x`.

6. **File Laporan `/root/lab/lab01-report.txt`:**
   - File `/root/lab/lab01-report.txt` tersedia, memiliki kunci `web_image=nginx:1.27-alpine` dan `web2_served=<versi>` yang keduanya tidak kosong, serta nilai `web2_served` cocok dengan versi `1.29`.

7. **Output Verifier:**
   - Menjalankan `verify/verify.sh` mencetak 6 baris `PASS:` dan diakhiri dengan `RESULT: PASS (6/6)` serta kode keluar `0`.
