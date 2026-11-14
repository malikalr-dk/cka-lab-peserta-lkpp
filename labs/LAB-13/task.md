# LAB-13 — NetworkPolicy: Default-Deny dan Allow-List Ingress

Tujuan: mengisolasi trafik masuk (*ingress*) ke Pod aplikasi `demo` dengan `NetworkPolicy` yang ditegakkan CNI kluster — dimulai dari kebijakan *default-deny* yang menutup seluruh trafik masuk, lalu menambahkan aturan *allow-list* yang hanya mengizinkan Pod berlabel `role=client` pada port `9898`.

## Konteks & State Awal

- Skrip starter telah menyiapkan namespace `cka-lab13` beserta objek berikut:
  - `Deployment` `demo` — image `docker.io/stefanprodan/podinfo:6.7.1`, containerPort `9898`, label `app: demo`, `imagePullPolicy: IfNotPresent`, readiness probe `GET /healthz`.
  - `Service` `demo` — `ClusterIP`, port `9898` → `targetPort 9898`, selector `app: demo`.
  - `Deployment` `client` — image `busybox:1.37` menjalankan `sleep 3600`, label `role: client`.
  - `Pod` `intruder` — image `busybox:1.37` menjalankan `sleep 3600`, label `role: intruder`.
- Sebelum ada `NetworkPolicy`, baik Pod `client` (`role=client`) maupun Pod `intruder` (`role=intruder`) dapat mengakses `http://demo:9898/healthz`.
- Selalu gunakan `imagePullPolicy: IfNotPresent` untuk objek baru (node memakai cache image lokal).
- Semua pengujian dilakukan dengan `kubectl exec` ke Pod yang sudah berjalan, dan **selalu beri batas waktu** (`wget -T 3`) supaya jalur yang diblokir gagal cepat, bukan menggantung.

## Tugas

1. **Terapkan Default-Deny Ingress pada `demo` dan Buktikan Akses Terblokir:**
   - Buat sebuah `NetworkPolicy` di namespace `cka-lab13` yang memilih Pod berlabel `app: demo` (`podSelector.matchLabels.app: demo`), dengan `policyTypes: ["Ingress"]` dan `ingress: []` sehingga seluruh trafik masuk ditolak.
   - Buktikan bahwa permintaan HTTP dari Pod `intruder` (`role=intruder`) kini **gagal / time out**:
     `kubectl -n cka-lab13 exec pod/intruder -- wget -qO- -T 3 http://demo:9898/healthz`
   - Perintah di atas harus keluar dengan status bukan `0` dan tidak mencetak body apa pun.

2. **Izinkan Hanya Klien Berlabel `role=client` pada Port `9898`:**
   - Perbarui `NetworkPolicy` tersebut (atau tambahkan aturan `ingress`) sehingga trafik masuk ke Pod `app: demo` **hanya** diizinkan bila berasal dari Pod di namespace yang sama dengan label `role: client` menuju port `TCP 9898`.
   - Buktikan dari Pod `client` bahwa permintaan HTTP **berhasil**:
     `kubectl -n cka-lab13 exec deploy/client -- wget -qO- -T 3 http://demo:9898/healthz`
   - Pastikan akses dari Pod `intruder` (`role=intruder`) tetap **terblokir**, dan akses dari `client` ke port lain (misalnya `8080`) juga **terblokir**:
     `kubectl -n cka-lab13 exec deploy/client -- wget -qO- -T 3 http://demo:8080/`

3. **Verifikasi Konektivitas Akhir:**
   - Tiga hasil di atas harus berlaku bersamaan: dari `client` → `demo:9898` **berhasil (exit 0)**, dari `intruder` → `demo:9898` **gagal**, dari `client` → `demo:8080` **gagal**.
   - Jangan mengubah atau menghapus label `app: demo` pada Pod aplikasi dan `role: client` pada Pod klien — kedua label itulah kunci kebijakannya.

## Bring Your Own Image (opsional)

Kalau aplikasi internal Anda ingin dipakai sebagai target kebijakan alih-alih `podinfo`, tulis deklarasi di node control-plane **sebelum** starter dijalankan:

```text
/root/lab/lab13-image.txt
image=<registry>/<nama>:<tag>
port=<port HTTP aplikasi>
path=<health path, mis. /healthz>
```

Syarat:

1. Tag ter-pin — tag `latest` ditolak oleh `starter/setup.sh`.
2. Aplikasi listen HTTP di `port` dan menjawab status 2xx di `path`; `path` dipakai readiness probe, jadi `Deployment demo` hanya menjadi `Ready` kalau aplikasinya benar-benar melayani jalur itu.
3. Image sudah di-import trainer ke cache node pada H-1 — node peserta tidak menarik image dari registry saat kelas.

Tanpa file tersebut, lab memakai default `docker.io/stefanprodan/podinfo:6.7.1`, port `9898`, path `/healthz`. Verifier membaca file yang sama untuk port dan path, dan **tidak** memeriksa nama image: yang dinilai hanya perilaku — klien berlabel `role=client` lolos di port yang dideklarasikan, sementara `role=intruder` dan port lain tetap terblokir.
