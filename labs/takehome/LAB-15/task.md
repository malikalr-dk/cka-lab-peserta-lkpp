# LAB-15 — NetworkPolicy: Default-Deny dan Allow-List Ingress

Tujuan: pasang NetworkPolicy default-deny lalu allow-list ke Pod `demo`; buktikan client lolos di 9898, intruder dan port lain gagal.

## Konteks & State Awal

- Starter sudah bikin namespace `cka-lab13` beserta objek berikut:
  - `Deployment` `demo`: image `docker.io/stefanprodan/podinfo:6.7.1`, containerPort `9898`, label `app: demo`, `imagePullPolicy: IfNotPresent`, readiness probe `GET /healthz`.
  - `Service` `demo`: `ClusterIP`, port `9898` → `targetPort 9898`, selector `app: demo`.
  - `Deployment` `client`: image `busybox:1.37` menjalankan `sleep 3600`, label `role: client`.
  - `Pod` `intruder`: image `busybox:1.37` menjalankan `sleep 3600`, label `role: intruder`.
- Sebelum ada `NetworkPolicy`, Pod `client` (`role=client`) dan Pod `intruder` (`role=intruder`) sama-sama bisa akses `http://demo:9898/healthz`.
- Pakai `imagePullPolicy: IfNotPresent` untuk objek baru (node pakai cache image lokal).
- Uji lewat `kubectl exec` ke Pod yang jalan, dan **selalu kasih timeout** (`wget -T 3`) supaya jalur yang diblokir gagal cepat, bukan menggantung.

## Tugas

1. **Pasang default-deny ingress untuk Pod `demo`:**
   - Buat `NetworkPolicy` di namespace `cka-lab13` yang memilih Pod berlabel `app: demo` (`podSelector.matchLabels.app: demo`), dengan `policyTypes: ["Ingress"]` dan `ingress: []` sehingga seluruh trafik masuk ditolak.
   - Buktikan permintaan HTTP dari Pod `intruder` (`role=intruder`) **gagal / time out**:
     `kubectl -n cka-lab13 exec pod/intruder -- wget -qO- -T 3 http://demo:9898/healthz`
   - Perintah di atas harus keluar dengan status bukan `0` dan tidak mencetak body apa pun.

2. **Izinkan hanya Pod `role=client` ke port 9898:**
   - Perbarui `NetworkPolicy` tersebut (atau tambahkan aturan `ingress`) sehingga trafik masuk ke Pod `app: demo` **hanya** diizinkan bila berasal dari Pod di namespace yang sama dengan label `role: client` menuju port `TCP 9898`.
   - Buktikan dari Pod `client` bahwa permintaan HTTP **berhasil**:
     `kubectl -n cka-lab13 exec deploy/client -- wget -qO- -T 3 http://demo:9898/healthz`
   - Pastikan akses dari Pod `intruder` (`role=intruder`) tetap **terblokir**, dan akses dari `client` ke port lain (misalnya `8080`) juga **terblokir**:
     `kubectl -n cka-lab13 exec deploy/client -- wget -qO- -T 3 http://demo:8080/`

3. **Cek akhir: client lolos, intruder ditolak:**
   - Tiga hasil di atas harus berlaku bersamaan: dari `client` → `demo:9898` **berhasil (exit 0)**, dari `intruder` → `demo:9898` **gagal**, dari `client` → `demo:8080` **gagal**.
   - Jangan ubah atau hapus label `app: demo` pada Pod aplikasi dan `role: client` pada Pod klien. Kedua label itu kunci kebijakannya.

## Bring Your Own Image (opsional)

Kalau mau pakai aplikasi internal sebagai target kebijakan, bukan `podinfo`, tulis deklarasi di node control-plane **sebelum** starter dijalankan:

```text
/root/lab/lab13-image.txt
image=<registry>/<nama>:<tag>
port=<port HTTP aplikasi>
path=<health path, mis. /healthz>
```

Syarat:

1. Tag ter-pin: tag `latest` ditolak oleh `starter/setup.sh`.
2. Aplikasi listen HTTP di `port` dan menjawab status 2xx di `path`; `path` dipakai readiness probe, jadi `Deployment demo` hanya jadi `Ready` kalau aplikasi benar-benar melayani jalur itu.
3. Image ditarik node saat pod pertama kali dibuat. Untuk registry internal, trainer menyiapkan aksesnya sebelum kelas.

Tanpa file tersebut, lab memakai default `docker.io/stefanprodan/podinfo:6.7.1`, port `9898`, path `/healthz`. Verifier membaca file yang sama untuk port dan path, dan **tidak** memeriksa nama image: yang dinilai hanya perilaku (klien berlabel `role=client` lolos di port yang dideklarasikan, sementara `role=intruder` dan port lain tetap terblokir).