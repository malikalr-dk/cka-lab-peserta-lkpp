# Expected Result — LAB-01

`verify/verify.sh` menilai state akhir di node `cka-pN-cp`:

1. **Namespace `gisp-app`:**
   - Namespace `gisp-app` ada di kluster dan memiliki fase `Active`.

2. **Pod imperatif `web` (`nginx:1.27-alpine`):**
   - Pod `web` di namespace `gisp-app` berstatus `Running` (kontainer siap) dan menjalankan image `nginx:1.27-alpine`.

3. **Pod deklaratif `web2` (`nginx:1.29-alpine`):**
   - Pod `web2` di namespace `gisp-app` berstatus `Running` (kontainer siap) dan menjalankan image `nginx:1.29-alpine`.

4. **Manifest generate client-side (`/root/lab/lab01-pod.yaml`):**
   - File `/root/lab/lab01-pod.yaml` ada di disk, merepresentasikan objek `Pod/web2`, dan perintah `kubectl -n gisp-app apply --dry-run=server -f /root/lab/lab01-pod.yaml` selesai dengan kode keluar `0`.

5. **Bukti HTTP dan versi nginx di `web2`:**
   - Eksekusi `kubectl -n gisp-app exec web2 -- wget -qO- http://127.0.0.1/` dan `kubectl -n gisp-app exec web2 -- nginx -v` berhasil dan melaporkan versi `1.29.x`.

6. **File laporan `/root/lab/lab01-report.txt`:**
   - File `/root/lab/lab01-report.txt` tersedia, memiliki kunci `web_image=nginx:1.27-alpine` dan `web2_served=<versi>` yang keduanya tidak kosong, serta nilai `web2_served` cocok dengan versi `1.29`.

7. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 6 baris `PASS:` dan diakhiri dengan `RESULT: PASS (6/6)` serta kode keluar `0`.