# Expected Result — LAB-12

State akhir yang dinilai oleh `verify/verify.sh` di node `cka-pN-cp` (lab ini merupakan gerbang penutup Day 3; seluruh komponen wajib ada dan berfungsi):

1. **ConfigMap `app-config`:**
   - `ConfigMap` `app-config` tersedia di namespace `cka-lab12` dengan data `GREETING=halo-lab12`.

2. **PersistentVolumeClaim `portal-data`:**
   - `PVC` `portal-data` tersedia di namespace `cka-lab12` dengan `storageClassName: local-path`, kapasitas `1Gi`, dan berstatus `Bound`.

3. **Deployment `portal` (3/3 Ready, Env dari ConfigMap, Volume Mount PVC):**
   - `Deployment` `portal` di `cka-lab12` menggunakan image `nginx:1.27-alpine` dan memiliki `3/3` replika berstatus `Ready`.
   - Spesifikasi container pada `Deployment` `portal` mereferensikan `ConfigMap` `app-config` (`envFrom` atau `configMapKeyRef`), dan di dalam container yang berjalan variabel `GREETING` bernilai `halo-lab12`.
   - Spesifikasi Pod pada `Deployment` `portal` me-*mount* PVC `portal-data` pada path `/usr/share/nginx/html/data`.

4. **Service `portal`:**
   - `Service` `portal` di `cka-lab12` bertipe `ClusterIP` pada port `80` dan memiliki `3` endpoint Pod yang aktif.

5. **Ingress `portal-ingress`:**
   - `Ingress` `portal-ingress` di `cka-lab12` memiliki host `portal.lab.local`, path `/`, dan mengarah ke `Service` `portal` pada port `80`.

6. **Uji HTTP End-to-End melalui Traefik (`localhost:30081`):**
   - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/` mengembalikan `HTTP 200` beserta halaman sambutan nginx.
   - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt` mengembalikan `HTTP 200` dengan isi non-kosong (`halo-lab12`).

7. **Output Verifier:**
   - Menjalankan `verify/verify.sh` mencetak 9 baris `PASS:` dan diakhiri dengan `RESULT: PASS (9/9)` serta kode keluar `0`.
