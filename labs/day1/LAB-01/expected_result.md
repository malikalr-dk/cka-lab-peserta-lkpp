# Expected Result — LAB-01

`verify/verify.sh` menilai state akhir di node `cka-pN-cp`. Satu Pod saja yang berjalan.

1. **Namespace `gisp-app`:**
   - Namespace `gisp-app` ada di kluster dan memiliki fase `Active`.

2. **Spec Pod `web` sudah `nginx:1.29-alpine`:**
   - Pod `web` berstatus `Running` dan `spec.containers[0].image` = `nginx:1.29-alpine`, hasil `kubectl set image pod/web web=nginx:1.29-alpine`.

3. **Image yang dipakai container juga 1.29:**
   - `status.containerStatuses[0].image` = `nginx:1.29-alpine`, jadi kubelet benar-benar memakai image baru, bukan hanya mengubah spec.

4. **Versi nginx di dalam container:**
   - `kubectl -n gisp-app exec web -- nginx -v` melaporkan `1.29.x`.

5. **File laporan `/root/lab/lab01-report.txt`:**
   - Berisi `web_image_before=nginx:1.27-alpine` dan `web_image_after=nginx:1.29-alpine`.

6. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 5 baris `PASS:` dan diakhiri `RESULT: PASS (5/5)` dengan kode keluar `0`.
