# LAB-01 — Imperative `kubectl` & Client-Side Manifest Generation

Tujuan: membuat namespace dan Pod secara imperatif menggunakan `kubectl run`, menghasilkan manifest YAML secara *client-side* dengan `--dry-run=client -o yaml` lalu menerapkannya menggunakan `kubectl apply -f`, menginspeksi kesehatan serta versi `nginx` di dalam masing-masing Pod menggunakan `kubectl get`, `kubectl describe`, `kubectl logs`, dan `kubectl exec`, serta menuliskan laporan hasil verifikasi.

## Konteks & State Awal

- Anda bekerja di node control-plane (`cka-pN-cp`) sebagai `root`.
- Direktori kerja `/root/lab` telah disiapkan oleh skrip starter, sementara namespace `lab01` belum ada.
- Seluruh image latihan sudah tersedia di cache lokal containerd di setiap node:
  - `nginx:1.27-alpine`
  - `nginx:1.29-alpine`
  - `busybox:1.37`

## Tugas

Bekerjalah di namespace `lab01` dari node control-plane:

1. **Buat Namespace `lab01`:**
   - Buat namespace baru bernama `lab01` menggunakan perintah imperatif `kubectl create namespace lab01`.

2. **Jalankan Pod `web` Secara Imperatif:**
   - Di namespace `lab01`, jalankan sebuah Pod bernama `web` yang menggunakan image `nginx:1.27-alpine` secara langsung dengan `kubectl run`:
     `kubectl -n lab01 run web --image=nginx:1.27-alpine`

3. **Hasilkan Manifest YAML Secara Client-Side & Terapkan (`web2`):**
   - Hasilkan manifest YAML untuk Pod bernama `web2` di namespace `lab01` dengan image `nginx:1.29-alpine` tanpa mengirimkannya ke API server terlebih dahulu:
     `kubectl -n lab01 run web2 --image=nginx:1.29-alpine --dry-run=client -o yaml > /root/lab/lab01-pod.yaml`
   - Terapkan file manifest tersebut ke kluster:
     `kubectl -n lab01 apply -f /root/lab/lab01-pod.yaml`

4. **Buktikan Kesehatan Kedua Pod & Versi `nginx` yang Dilayani:**
   - Pastikan kedua Pod (`web` dan `web2`) berstatus `Running` dan `Ready` menggunakan:
     - `kubectl -n lab01 get pods -o wide`
     - `kubectl -n lab01 describe pod web web2`
     - `kubectl -n lab01 logs web` dan `kubectl -n lab01 logs web2`
   - Buktikan respons HTTP dan versi `nginx` yang berjalan di dalam masing-masing Pod menggunakan `kubectl exec`:
     - `kubectl -n lab01 exec web -- wget -qO- http://127.0.0.1/`
     - `kubectl -n lab01 exec web -- nginx -v`
     - `kubectl -n lab01 exec web2 -- wget -qO- http://127.0.0.1/`
     - `kubectl -n lab01 exec web2 -- nginx -v`

5. **Tulis File Laporan `/root/lab/lab01-report.txt`:**
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
