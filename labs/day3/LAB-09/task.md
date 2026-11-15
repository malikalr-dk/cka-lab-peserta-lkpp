# LAB-09 — Services, Endpoints, dan DNS (Tanpa Ingress)

Tujuan: buat `Service` `ClusterIP` untuk `demo` di `gisp-app`, isi endpoint. Bukti: DNS resolve dan HTTP `200` ke `/healthz`.

## Konteks & State Awal

- `starter/setup.sh` sudah bikin namespace `gisp-app` berisi:
  - `Deployment` `demo`, `1` replika, label pod `app=demo`
  - Image `docker.io/stefanprodan/podinfo:6.7.1` dengan `imagePullPolicy: IfNotPresent`, `containerPort: 9898`
  - `readinessProbe` ke `/healthz` port `9898`
  - Pod klien `client`, image `busybox:1.37`, perintah `sleep 3600`, `imagePullPolicy: IfNotPresent`
- Yang **belum** ada: `Service` untuk deployment itu. Itu tugasmu.
- Aplikasi `podinfo` listen port `9898` dan punya `/healthz`, `/version`, `/metrics`.
- Image default sudah ada di golden image tiap node. Node menarik image lain saat pod pertama dibuat; biarkan `imagePullPolicy: IfNotPresent`.

## Tugas

1. **Service `demo` bertipe `ClusterIP`:**
   - Nama `demo`, `type: ClusterIP`, `port: 9898`, `targetPort: 9898`, selector `app=demo`.
   - Cara cepat: `kubectl -n gisp-app expose deployment demo --name=demo --port=9898 --target-port=9898 --type=ClusterIP`
   - Periksa hasilnya: `kubectl -n gisp-app get service demo -o wide`

2. **Periksa `Endpoints` (atau `EndpointSlice`):**
   - `kubectl -n gisp-app get endpoints demo`
   - `kubectl -n gisp-app get endpointslices -l kubernetes.io/service-name=demo`
   - Pastikan ada minimal satu alamat Pod beserta port `9898` di dalamnya. Kalau kosong, selector Service tidak cocok dengan label Pod. Periksa `kubectl -n gisp-app get pods --show-labels`.

3. **Buktikan resolusi DNS dari dalam Pod klien:**
   - `kubectl -n gisp-app exec client -- nslookup demo.gisp-app.svc.cluster.local`
   - Output harus memuat blok `Name:` dengan minimal satu baris `Address:`.

4. **Buktikan jalur HTTP-nya juga hidup:**
   - `kubectl -n gisp-app exec client -- wget -qO- http://demo.gisp-app.svc.cluster.local:9898/healthz`
   - Respons `200` dengan body singkat (podinfo membalas `ok`) berarti Service, Endpoints, DNS, dan aplikasi semuanya benar.

## Apa yang Diverifikasi

`verify/verify.sh` menjalankan lima pemeriksaan perilaku (bukan pemeriksaan nama objek semata):

1. `Deployment` `gisp-app/demo` punya `readyReplicas=1`.
2. `Service` `gisp-app/demo` bertipe `ClusterIP`, mendapat alamat `clusterIP`, dan melayani port yang dideklarasikan (`9898` secara default).
3. `Endpoints`/`EndpointSlice` untuk Service `demo` memuat minimal satu alamat siap pakai.
4. `nslookup demo.gisp-app.svc.cluster.local` dari dalam Pod mengembalikan minimal satu A record.
5. `HTTP GET http://demo.gisp-app.svc.cluster.local:<port><path>` dari dalam Pod mengembalikan `200`.

Verifier **tidak** memeriksa nama image. Yang dinilai adalah perilaku di atas, jadi image aplikasi apa pun yang listen HTTP dan punya path health bisa dipakai (lihat bagian berikut).

## Bring your own image (BYO)

Kalau mau pakai image internal sendiri mengganti `podinfo`, pastikan registry-nya bisa dijangkau dari node lab. Trainer menyiapkan akses itu sebelum kelas. Setelah itu tulis deklarasi di control-plane pada `/root/lab/lab09-image.txt`, tepat tiga baris:

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
- Image ditarik node saat pod pertama kali dibuat (`imagePullPolicy: IfNotPresent`).
- Setelah file ditulis, jalankan ulang `bash starter/setup.sh` (idempotent, membaca deklarasi tersebut) atau ganti image Deployment secara manual: `kubectl -n gisp-app set image deployment/demo demo=<image>:<tag>`.
- Kalau file itu tidak ada, verifier memakai default `docker.io/stefanprodan/podinfo:6.7.1`, port `9898`, path `/healthz`.
- `Service` yang dibuat tetap memakai port dari deklarasi (default `9898`), bukan port lain.

Kalau image diubah tanpa menulis deklarasi, verifier tetap memakai default; `Service`-mu gagal di pemeriksaan 2 dan 5, bukan karena image-nya salah.

## Batasan

- Tanpa Ingress, tanpa `NodePort`, tanpa `LoadBalancer`: cukup satu `Service` `ClusterIP` bernama `demo`.
- Jangan ubah `Deployment` `demo` selain urusan image (BYO), dan jangan hapus pod klien `client`. Verifier memakainya untuk uji DNS/HTTP.
- Jangan sentuh `kube-system`, konfigurasi CoreDNS, atau label/selector `app=demo`.
- Jangan memakai referensi image yang tidak bisa dijangkau dari node; pod akan berakhir `ImagePullBackOff`.