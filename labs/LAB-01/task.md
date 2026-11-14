# LAB-01 — Imperative `kubectl` & Client-Side Manifest Generation

Tujuan: buat namespace dan Pod imperatif, apply manifest client-side. Bukti: Pod Running dan laporan lab.

## Konteks & State Awal

- Kerja dari node control-plane (`cka-pN-cp`) sebagai `root`.
- Starter sudah siapkan direktori `/root/lab`; namespace `lab01` belum ada.
- Image latihan sudah di cache lokal containerd di tiap node:
  - `nginx:1.27-alpine`
  - `nginx:1.29-alpine`
  - `busybox:1.37`

## Tugas

Kerja di namespace `lab01` dari control-plane:

1. **Buat namespace `lab01`:**
   - Buat namespace baru bernama `lab01` menggunakan perintah imperatif `kubectl create namespace lab01`.

2. **Jalankan Pod `web` dengan `kubectl run`:**
   - Di namespace `lab01`, jalankan sebuah Pod bernama `web` yang menggunakan image `nginx:1.27-alpine` secara langsung dengan `kubectl run`:
     `kubectl -n lab01 run web --image=nginx:1.27-alpine`

3. **Generate manifest client-side lalu apply `web2`:**
   - Hasilkan manifest YAML untuk Pod bernama `web2` di namespace `lab01` dengan image `nginx:1.29-alpine` tanpa mengirimkannya ke API server terlebih dahulu:
     `kubectl -n lab01 run web2 --image=nginx:1.29-alpine --dry-run=client -o yaml > /root/lab/lab01-pod.yaml`
   - Terapkan file manifest tersebut ke kluster:
     `kubectl -n lab01 apply -f /root/lab/lab01-pod.yaml`

4. **Cek kesehatan Pod dan versi nginx:**
   - Pastikan kedua Pod (`web` dan `web2`) berstatus `Running` dan `Ready` menggunakan:
     - `kubectl -n lab01 get pods -o wide`
     - `kubectl -n lab01 describe pod web web2`
     - `kubectl -n lab01 logs web` dan `kubectl -n lab01 logs web2`
   - Buktikan respons HTTP dan versi `nginx` yang berjalan di dalam masing-masing Pod menggunakan `kubectl exec`:
     - `kubectl -n lab01 exec web -- wget -qO- http://127.0.0.1/`
     - `kubectl -n lab01 exec web -- nginx -v`
     - `kubectl -n lab01 exec web2 -- wget -qO- http://127.0.0.1/`
     - `kubectl -n lab01 exec web2 -- nginx -v`

5. **Tulis laporan `/root/lab/lab01-report.txt`:**
   - Buat file `/root/lab/lab01-report.txt` yang berisi tepat dua baris berikut:
     ```text
     web_image=nginx:1.27-alpine
     web2_served=<nginx version output from inside web2>
     ```
     *(Contoh nilai `web2_served`: `nginx version: nginx/1.29.8` atau `nginx/1.29.8` dari keluaran `kubectl -n lab01 exec web2 -- nginx -v`)*

## Apa yang Diverifikasi

1. Namespace `lab01` tersedia dan berstatus `Active`.
2. Pod `web` di namespace `lab01` berstatus `Running` dengan image `nginx:1.27-alpine`.
3. Pod `web2` di namespace `lab01` berstatus `Running` dengan image `nginx:1.29-alpine`.
4. File `/root/lab/lab01-pod.yaml` tersedia, terdefinisi sebagai `Pod/web2`, dan valid saat diuji dengan `kubectl apply --dry-run=server -f /root/lab/lab01-pod.yaml`.
5. Versi `nginx` yang dilaporkan dari dalam Pod `web2` adalah `1.29.x` (dibuktikan melalui `kubectl exec web2 -- wget -qO- http://127.0.0.1/` dan `kubectl exec web2 -- nginx -v`).
6. File `/root/lab/lab01-report.txt` memiliki kedua kunci (`web_image` dan `web2_served`) dengan nilai tidak kosong serta `web2_served` memuat versi `1.29`.

## Batasan

- Gunakan hanya tag image yang sudah ada di cache lokal (`nginx:1.27-alpine`, `nginx:1.29-alpine`, `busybox:1.37`).
- Jangan menghapus Pod `web` maupun `web2` atau file `/root/lab/lab01-pod.yaml` dan `/root/lab/lab01-report.txt` sebelum menjalankan `verify/verify.sh`.
- Seluruh pembuatan dan inspeksi beban kerja wajib dilakukan menggunakan `kubectl` melalui Kubernetes API.