# LAB-09 — Services, Endpoints, dan DNS (Tanpa Ingress)

Tujuan: mengekspos sebuah aplikasi (`Deployment` `demo`) di dalam kluster memakai `Service` bertipe `ClusterIP`, membuktikan objek `Endpoints`/`EndpointSlice` benar-benar terisi alamat Pod, lalu membuktikan bahwa CoreDNS bisa me-resolve nama Service tersebut dan satu `HTTP GET` ke path health-nya mengembalikan `200`.

## Konteks & State Awal

- Namespace `cka-lab09` sudah dibuat oleh `starter/setup.sh`, berisi:
  - `Deployment` `demo` — `1` replika, label Pod `app=demo`
  - Image `docker.io/stefanprodan/podinfo:6.7.1` dengan `imagePullPolicy: IfNotPresent`, `containerPort: 9898`
  - `readinessProbe` ke `/healthz` pada port `9898`
  - Pod klien `client` — image `busybox:1.37`, perintah `sleep 3600`, `imagePullPolicy: IfNotPresent`
- Yang **belum** ada: `Service` untuk Deployment tersebut. Itu tugasmu.
- Aplikasi `podinfo` mendengarkan di port `9898` dan menyediakan `/healthz`, `/version`, `/metrics`.
- Semua image sudah ada di cache `containerd` setiap node. Node lab tidak menarik image dari registry publik, jadi jangan hapus `imagePullPolicy: IfNotPresent` dan jangan menambah Pod dengan image yang belum ada di cache.

## Tugas

1. **Service `demo` bertipe `ClusterIP`:**
   - Nama `demo`, `type: ClusterIP`, `port: 9898`, `targetPort: 9898`, selector `app=demo`.
   - Cara cepat: `kubectl -n cka-lab09 expose deployment demo --name=demo --port=9898 --target-port=9898 --type=ClusterIP`
   - Periksa hasilnya: `kubectl -n cka-lab09 get service demo -o wide`

2. **Periksa `Endpoints` (atau `EndpointSlice`):**
   - `kubectl -n cka-lab09 get endpoints demo`
   - `kubectl -n cka-lab09 get endpointslices -l kubernetes.io/service-name=demo`
   - Pastikan ada minimal satu alamat Pod beserta port `9898` di dalamnya. Kalau kosong, selector Service tidak cocok dengan label Pod — periksa `kubectl -n cka-lab09 get pods --show-labels`.

3. **Buktikan resolusi DNS dari dalam Pod klien:**
   - `kubectl -n cka-lab09 exec client -- nslookup demo.cka-lab09.svc.cluster.local`
   - Output harus memuat blok `Name:` dengan minimal satu baris `Address:`.

4. **Buktikan jalur HTTP-nya juga hidup:**
   - `kubectl -n cka-lab09 exec client -- wget -qO- http://demo.cka-lab09.svc.cluster.local:9898/healthz`
   - Respons `200` dengan body singkat (podinfo membalas `ok`) berarti Service, Endpoints, DNS, dan aplikasi semuanya benar.

## Apa yang Diverifikasi

`verify/verify.sh` menjalankan lima pemeriksaan perilaku (bukan pemeriksaan nama objek semata):

1. `Deployment` `cka-lab09/demo` punya `readyReplicas=1`.
2. `Service` `cka-lab09/demo` bertipe `ClusterIP`, mendapat alamat `clusterIP`, dan melayani port yang dideklarasikan (`9898` secara default).
3. `Endpoints`/`EndpointSlice` untuk Service `demo` memuat minimal satu alamat siap pakai.
4. `nslookup demo.cka-lab09.svc.cluster.local` dari dalam Pod mengembalikan minimal satu A record.
5. `HTTP GET http://demo.cka-lab09.svc.cluster.local:<port><path>` dari dalam Pod mengembalikan `200`.

Verifier **tidak** memeriksa nama image. Yang dinilai adalah perilaku di atas, jadi image aplikasi apa pun yang listen HTTP dan punya path health bisa dipakai (lihat bagian berikut).

## Bring your own image (BYO)

Kalau kamu ingin memakai image aplikasi internal sendiri sebagai pengganti `podinfo`, trainer harus menyiapkan image itu **sebelum kelas** (node lab tidak bisa menarik dari registry publik). Setelah image masuk cache node, tulis deklarasi di node control-plane pada file `/root/lab/lab09-image.txt`, tepat tiga baris:

```text
image=<registry>/<nama>:<tag>
port=<port tempat aplikasi listen>
path=<path health, mis. /healthz>
```

Contoh:

```text
image=registry.internal.local/gisp/api:1.4.2
port=8080
path=/healthz
```

Aturan yang mengikat:

- **Tag harus ter-pin, jangan `latest`.** `starter/setup.sh` menolak referensi tanpa tag atau `:latest`.
- Aplikasi harus listen HTTP pada `port` yang dideklarasikan dan membalas `200` pada `path` yang dideklarasikan.
- Image harus sudah di-import ke cache node **H-1 oleh trainer**, bukan saat kelas berjalan.
- Setelah file ditulis, jalankan ulang `bash starter/setup.sh` (idempotent, membaca deklarasi tersebut) atau ganti image Deployment secara manual: `kubectl -n cka-lab09 set image deployment/demo demo=<image>:<tag>`.
- Kalau file itu tidak ada, verifier memakai default `docker.io/stefanprodan/podinfo:6.7.1`, port `9898`, path `/healthz`.
- Service yang kamu buat tetap memakai port dari deklarasi (default `9898`), bukan port lain.

Kalau kamu mengubah image tanpa menulis deklarasi, verifier tetap memakai default — Service-mu akan gagal di pemeriksaan 2 dan 5, bukan karena image-nya salah.

## Batasan

- Tanpa Ingress, tanpa `NodePort`, tanpa `LoadBalancer`: cukup satu `Service` `ClusterIP` bernama `demo`.
- Jangan mengubah `Deployment` `demo` selain urusan image (BYO), dan jangan menghapus Pod klien `client` — verifier memakainya untuk uji DNS/HTTP.
- Jangan menyentuh `kube-system`, konfigurasi CoreDNS, atau label/selector `app=demo`.
- Jangan membuat Pod baru dengan image yang belum ada di cache node (akan berakhir `ImagePullBackOff`).
- Tidak ada akses ke registry publik dari node lab.
