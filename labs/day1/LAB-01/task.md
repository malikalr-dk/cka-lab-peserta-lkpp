# LAB-01 — Containerize & Update Image dengan `kubectl`

Tujuan: jalankan satu Pod, perbarui image-nya di tempat, dan buktikan versi baru benar-benar berjalan.

## Konteks & State Awal

- **Starter (opsional):** `bash starter/setup.sh` hanya menyiapkan `/root/lab` dan nama namespace; lab tetap bisa dikerjakan tanpa itu.

- Kerja dari node control-plane (`cka-pN-cp`) sebagai `root`.
- Starter sudah siapkan direktori `/root/lab`; namespace `gisp-app` belum ada.
- Tag image latihan: `nginx:1.27-alpine` dan `nginx:1.29-alpine`.

## Tugas

Satu Pod saja, bernama `web`.

1. **Buat namespace `gisp-app`:**
   `kubectl create namespace gisp-app`

2. **Jalankan Pod `web` dengan tag lama:**
   `kubectl -n gisp-app run web --image=nginx:1.27-alpine`
   `kubectl -n gisp-app wait --for=condition=Ready pod/web --timeout=60s`
   `kubectl -n gisp-app exec web -- nginx -v`

3. **Perbarui image Pod `web` tanpa membuat objek baru:**
   `kubectl -n gisp-app set image pod/web web=nginx:1.29-alpine`
   `kubectl -n gisp-app exec web -- nginx -v`
   Kalau `exec` menjawab `container not found ("web")`, container lama sedang diganti. Tunggu beberapa detik, ulangi; bukan tanda Pod rusak.

4. **Tulis laporan `/root/lab/lab01-report.txt`:**
   Isi tepat dua baris:
   ```text
   web_image_before=nginx:1.27-alpine
   web_image_after=nginx:1.29-alpine
   ```

## Apa yang Diverifikasi

1. Namespace `gisp-app` tersedia dan berstatus `Active`.
2. Pod `web` berstatus `Running` dengan `spec.containers[0].image` = `nginx:1.29-alpine`.
3. Image yang dipakai container (`status.containerStatuses[0].image`) juga `nginx:1.29-alpine`, bukan hanya berubah di spec.
4. `kubectl exec web -- nginx -v` melaporkan `1.29.x`.
5. File `/root/lab/lab01-report.txt` memuat `web_image_before=nginx:1.27-alpine` dan `web_image_after=nginx:1.29-alpine`.

## Batasan

- Jangan ganti nama Pod `web` dan jangan buat Pod kedua; satu container saja.
- Jangan hapus Pod atau file laporan sebelum verifier dijalankan.
- Semua pembuatan dan inspeksi beban kerja lewat `kubectl`.
