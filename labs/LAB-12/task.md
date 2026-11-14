# LAB-12 — Mini Project: Aplikasi End-to-End di Kubernetes

Tujuan: bangun stack lengkap di `cka-lab12` (ConfigMap, PVC, Deployment, Service, Ingress). Bukti: HTTP Traefik dan isi `proof.txt`.

## Konteks & State Awal

- Starter hanya bikin namespace kosong `cka-lab12`, plus Traefik aktif di **NodePort `30081`** dan `StorageClass` `local-path` tersedia.
- Lima objek di `cka-lab12` harus dibuat sendiri.
- Container pakai `imagePullPolicy: IfNotPresent` karena image dari cache lokal node.
- **Catatan `local-path` multi-pod:** `local-path` bikin direktori per node; pahami bagaimana `/usr/share/nginx/html/data/proof.txt` terbaca lewat Service/Ingress (initContainer, startup, salin ke pod jalan, atau penjadwalan) agar `curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt` selalu mengembalikan isi valid.

## Tugas

Bangun seluruh komponen berikut di dalam namespace `cka-lab12`:

1. **ConfigMap (`app-config`):**
   - Buat `ConfigMap` `app-config` di `cka-lab12` dengan key-value:
     - `GREETING=halo-lab12`

2. **PersistentVolumeClaim (`portal-data`):**
   - Buat `PersistentVolumeClaim` `portal-data` di `cka-lab12` dengan:
     - `storageClassName: local-path`
     - `accessModes`: `ReadWriteOnce`
     - `resources.requests.storage`: `1Gi`

3. **Deployment (`portal`):**
   - Buat `Deployment` `portal` di `cka-lab12` dengan:
     - Replicas: `3`
     - Image container: `nginx:1.27-alpine` (`imagePullPolicy: IfNotPresent`)
     - Import env `GREETING` dari `ConfigMap` `app-config` (`envFrom` atau `env[].valueFrom.configMapKeyRef`) sehingga `GREETING=halo-lab12` aktif di container.
     - Mount PVC `portal-data` ke `/usr/share/nginx/html/data` di container.
   - Tulis `halo-lab12` ke `/usr/share/nginx/html/data/proof.txt` pada volume itu.

4. **Service (`portal`):**
   - Buat `Service` `ClusterIP` `portal` di `cka-lab12` port `80` (`targetPort: 80`) mengarah ke pod `Deployment` `portal`.

5. **Ingress (`portal-ingress`):**
   - Buat `Ingress` `portal-ingress` di `cka-lab12` (`ingressClassName: traefik`) dengan:
     - Host: `portal.lab.local`
     - Path: `/` (`pathType: Prefix`)
     - Backend: Service `portal` port `80`

6. **Verifikasi end-to-end:**
   - Pastikan 3 pod `portal` `Ready` (`3/3`).
   - Buktikan dari node (`cka-pN-cp`):
     - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/` mengembalikan `HTTP 200` (halaman nginx).
     - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt` mengembalikan `halo-lab12`.