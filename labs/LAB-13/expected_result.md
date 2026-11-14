# Expected Result — LAB-13

State akhir yang dinilai `verify/verify.sh` di node `cka-pN-cp`. Verifier *behaviour-based*:
nama image **tidak** pernah di-assert (supaya BYO jalan), yang dinilai hanya perilaku trafik
ke Pod `app=demo` pada port/path yang dideklarasikan.

Port dan path diambil dari `/root/lab/lab13-image.txt` bila ada; tanpa file itu dipakai default
`9898` dan `/healthz`. Port yang diuji-terlarang adalah `8080` (atau `8081` bila port deklarasi
`8080`).

1. **Workload starter di namespace `cka-lab13`:**
   - `Deployment` `demo` (`app=demo`, port `9898`, readiness probe `GET /healthz`) dan
     `Deployment` `client` (`role=client`) berstatus `Ready` (`readyReplicas >= 1`), serta
     `Pod` `intruder` (`role=intruder`) berstatus `Running`.
   - Ditunggu sampai 60 detik (30 poll @2s) sebelum dinilai supaya sandbox yang baru dibuat
     tidak menghasilkan FAIL palsu.

2. **`NetworkPolicy` yang memilih `app=demo`:**
   - Ada minimal satu `NetworkPolicy` di namespace `cka-lab13` yang `spec.podSelector`-nya
     mencakup Pod `app=demo`, baik `matchLabels.app: demo` maupun `podSelector` kosong
     (yang memilih semua Pod di namespace, termasuk `demo`).
   - Bentuk aturan `ingress` tidak diperiksa; yang menentukan lulus/tidak adalah perilaku di
     poin 3–5.

3. **Trafik yang diizinkan lolos:**
   - `HTTP GET http://demo:9898/healthz` dari Pod `role=client` **berhasil** (exit `0`,
     retry 10x @2s untuk memberi waktu pemrograman kebijakan oleh Calico).

4. **Trafik dari sumber di luar allow-list terblokir:**
   - `HTTP GET http://demo:9898/healthz` dari Pod `intruder` (`role=intruder`) **gagal**
     (exit bukan `0`, retry 10x @2s). Sebelum diukur, verifier lebih dulu membuktikan `exec`
     ke `intruder` berjalan (`sh -c 'echo ok'`) supaya `exec` yang rusak tidak terbaca sebagai
     "terblokir".

5. **Port selain port deklarasi terblokir:**
   - `HTTP GET http://demo:8080/` dari Pod `role=client` **gagal** (retry 5x @2s). Pesan PASS
     mencetak lama waktu kegagalan: drop kebijakan (timeout ~3s) berbeda dari `connection
     refused` (0s), yang berarti port itu memang tidak listen.
   - Catatan: assertion ini juga lulus sebelum kebijakan dibuat (aplikasi tidak listen di `8080`).
     Fungsinya menjaga regresi, bukan membedakan baseline dari solusi; yang membedakan adalah
     assertion 2 dan 4.

6. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 5 baris `PASS:` dan diakhiri
     `RESULT: PASS (5/5)` dengan kode keluar `0`.