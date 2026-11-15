# Expected Result — LAB-12

State akhir yang dinilai `verify/verify.sh` di node `cka-pN-cp` (lab penutup Day 3; semua komponen harus ada dan jalan):

1. **ConfigMap `app-config`:**
   - `ConfigMap` `app-config` ada di `cka-lab12` dengan data `GREETING=halo-lab12`.

2. **PersistentVolumeClaim `portal-data`:**
   - PVC `portal-data` ada di `cka-lab12` dengan `storageClassName: local-path`, kapasitas `1Gi`, status `Bound`.

3. **Deployment `portal` (3/3 Ready, Env dari ConfigMap, Volume Mount PVC):**
   - `Deployment` `portal` di `cka-lab12` memakai image `nginx:1.27-alpine` dan punya `3/3` replika `Ready`.
   - Spec container mereferensikan `ConfigMap` `app-config` (`envFrom` atau `configMapKeyRef`); env `GREETING` di container jalan = `halo-lab12`.
   - Spec pod `Deployment` `portal` mount PVC `portal-data` di `/usr/share/nginx/html/data`.

4. **Service `portal`:**
   - `Service` `portal` di `cka-lab12` bertipe `ClusterIP` port `80` dengan `3` endpoint pod aktif.

5. **Ingress `portal-ingress`:**
   - `Ingress` `portal-ingress` di `cka-lab12` host `portal.lab.local`, path `/`, backend ke `Service` `portal` port `80`.

6. **Uji HTTP End-to-End melalui Traefik (`localhost:30081`):**
   - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/` mengembalikan `HTTP 200` dan halaman nginx.
   - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt` mengembalikan `HTTP 200` dengan isi `halo-lab12`.

7. **Output Verifier:**
   - `verify/verify.sh` mencetak 9 baris `PASS:` lalu `RESULT: PASS (9/9)` dan exit code `0`.