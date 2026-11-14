# Expected Result — LAB-16

State akhir yang dinilai oleh `verify/verify.sh` di node `cka-pN-cp`:

1. **Part A — CustomResourceDefinition `configforges.lab.example.com` & Validasi OpenAPI:**
   - CRD `configforges.lab.example.com` berstatus `Established=True`, memiliki `scope: Namespaced`, dan `shortNames` memuat `cfgforge`.
   - Perintah `kubectl explain configforge.spec` berhasil menampilkan skema OpenAPI v3 yang mencantumkan field `data`.
   - Objek `ConfigForge` yang tidak valid (dengan panjang `spec.data` melebihi `maxLength: 40`) **ditolak** oleh API server.
   - Objek `ConfigForge` yang valid (misalnya `app-cfg` dengan `spec.data` `<= 40` karakter) tersedia dan dapat dibaca di namespace `cka-lab16`.

2. **Part B — Operator Traefik & Custom Resource `IngressRoute`:**
   - CRD `ingressroutes.traefik.io` berstatus `Established=True` dan `Deployment` `traefik` di namespace `traefik` memiliki kondisi `Available=True`.
   - Objek `IngressRoute` (`traefik.io/v1alpha1`, misalnya `app-route`) tersedia di namespace `cka-lab16` dengan aturan `Host(\`app.lab16.local\`)` yang mengarah ke `Service` `web` pada port `80`.
   - Permintaan HTTP melalui NodePort Traefik (`http://localhost:30082/` dengan header `Host: app.lab16.local`) berhasil direkonsiliasi dan mengembalikan halaman sambutan nginx (`Welcome to nginx!`).
   - Saat `IngressRoute` dihapus, permintaan yang sama ke `http://localhost:30082/` dengan header `Host: app.lab16.local` tidak lagi mengembalikan halaman nginx melainkan kode status HTTP `404` (diverifikasi secara otomatis oleh `verify/verify.sh`, yang kemudian memulihkan kembali `IngressRoute` peserta).

3. **Perilaku `reset/reset.sh` & Output Verifier:**
   - Skrip `reset/reset.sh` valid dan terkonfigurasi untuk menghapus namespace `cka-lab16` serta CRD `configforges.lab.example.com`, sembari membiarkan rilis Traefik tetap terpasang.
   - Menjalankan `verify/verify.sh` mencetak 9 baris `PASS:` dan diakhiri dengan `RESULT: PASS (9/9)` serta kode keluar `0`.
