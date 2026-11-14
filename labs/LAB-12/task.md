# LAB-12 — Mini Project: Aplikasi End-to-End di Kubernetes

Tujuan: membangun satu aplikasi utuh dari nol di namespace `cka-lab12` yang menggabungkan `ConfigMap`, `PersistentVolumeClaim` (`local-path`), `Deployment` (3 replika dengan environment variable dan volume mount), `Service` (`ClusterIP`), serta `Ingress` (`Traefik`), lalu membuktikan bahwa aplikasi dan berkas di dalam PVC dapat diakses melalui HTTP.

## Konteks & State Awal

- Skrip starter hanya menyiapkan namespace kosong `cka-lab12` (serta memastikan `Traefik` aktif pada **NodePort `30081`** dan `StorageClass` `local-path` tersedia).
- Anda wajib membangun kelima objek di namespace `cka-lab12` sendiri.
- Selalu gunakan `imagePullPolicy: IfNotPresent` pada container karena image diambil dari cache lokal node.
- **Catatan Penting tentang Multi-Pod & `local-path`:** Karena `local-path` membuat direktori penyimpanan lokal per node, pastikan Anda memahami bagaimana berkas `/usr/share/nginx/html/data/proof.txt` tersedia ketika di-probe melalui Service/Ingress (misalnya mengisi berkas melalui `initContainer`, perintah startup, menyalin ke Pod yang berjalan, atau menjadwalkan Pod sesuai kebutuhan) sehingga setiap request `curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt` selalu mengembalikan isi berkas yang valid.

## Tugas

Bangun seluruh komponen berikut di dalam namespace `cka-lab12`:

1. **ConfigMap (`app-config`):**
   - Buat sebuah `ConfigMap` bernama `app-config` di namespace `cka-lab12` yang memiliki pasangan key-value:
     - `GREETING=halo-lab12`

2. **PersistentVolumeClaim (`portal-data`):**
   - Buat sebuah `PersistentVolumeClaim` bernama `portal-data` di namespace `cka-lab12` dengan spesifikasi:
     - `storageClassName: local-path`
     - `accessModes`: `ReadWriteOnce`
     - `resources.requests.storage`: `1Gi`

3. **Deployment (`portal`):**
   - Buat sebuah `Deployment` bernama `portal` di namespace `cka-lab12` dengan spesifikasi:
     - Replicas: `3`
     - Image container: `nginx:1.27-alpine` (`imagePullPolicy: IfNotPresent`)
     - Mengimpor environment variable `GREETING` dari `ConfigMap` `app-config` (menggunakan `envFrom` atau `env[].valueFrom.configMapKeyRef`) sehingga variabel `GREETING=halo-lab12` aktif di dalam container.
     - Me-*mount* PVC `portal-data` ke path `/usr/share/nginx/html/data` di dalam container.
   - Tulis nilai `halo-lab12` ke dalam berkas `/usr/share/nginx/html/data/proof.txt` pada volume tersebut.

4. **Service (`portal`):**
   - Buat sebuah `Service` bertipe `ClusterIP` bernama `portal` di namespace `cka-lab12` pada port `80` (`targetPort: 80`) yang mengarah ke Pod milik Deployment `portal`.

5. **Ingress (`portal-ingress`):**
   - Buat sebuah `Ingress` bernama `portal-ingress` di namespace `cka-lab12` (`ingressClassName: traefik`) dengan aturan:
     - Host: `portal.lab.local`
     - Path: `/` (`pathType: Prefix`)
     - Backend: Service `portal` pada port `80`

6. **Verifikasi End-to-End:**
   - Pastikan ke-3 Pod `portal` berstatus `Ready` (`3/3`).
   - Buktikan dari node (`cka-pN-cp`) bahwa:
     - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/` mengembalikan respons `HTTP 200` (halaman nginx).
     - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt` mengembalikan `halo-lab12`.
