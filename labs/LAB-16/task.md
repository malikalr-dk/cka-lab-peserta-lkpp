# LAB-16 — CustomResourceDefinition (`ConfigForge`) dan Operator Berbasis CRD (Traefik `IngressRoute`)

Tujuan: memeriksa skema OpenAPI v3 pada *CustomResourceDefinition* (`CRD`) menggunakan `kubectl explain`, membuktikan validasi skema di sisi API server dengan membuat *Custom Resource* (`ConfigForge`) yang tidak valid dan yang valid, serta mengonfigurasi dan mengamati rekonsiliasi nyata oleh operator **Traefik** melalui *Custom Resource* `IngressRoute` (`traefik.io/v1alpha1`).

## Konteks & State Awal

- Skrip starter telah menyiapkan objek-objek berikut:
  - **Part A — CRD `ConfigForge`:**
    - `CustomResourceDefinition` bernama `configforges.lab.example.com`:
      - `group`: `lab.example.com`, `version`: `v1`, `kind`: `ConfigForge`, `shortNames`: `cfgforge`, `scope`: `Namespaced`
      - Skema OpenAPI v3: mewajibkan field `spec.data` bertipe `string` dengan aturan validasi panjang karakter `minLength: 1` dan `maxLength: 40`.
  - **Part B — Operator Traefik & Workload `web`:**
    - Rilis Helm **Traefik** di namespace `traefik` (dari chart lokal `/opt/lab/charts/traefik-42.4.0.tgz`) telah dikonfigurasi dengan provider Kubernetes CRD aktif (`providers.kubernetesCRD.enabled=true`) dan diekspos melalui `Service` bertipe `NodePort` pada port `80` -> NodePort `30082`.
    - CRD Traefik `ingressroutes.traefik.io` (`apiVersion: traefik.io/v1alpha1`, `kind: IngressRoute`) telah terdaftar dan berstatus `Established=True`.
    - Namespace `cka-lab16` berisi `Deployment` bernama `web` (`nginx:1.27-alpine`, `1` replika, `imagePullPolicy: IfNotPresent`) dan `Service` bernama `web` pada port `80`.
- Saat starter selesai dijalankan, **belum ada** objek `ConfigForge` maupun `IngressRoute` di namespace `cka-lab16`.
- **Perilaku `reset/reset.sh`:** skrip reset menghapus namespace `cka-lab16` beserta CRD `configforges.lab.example.com`, dan membiarkan rilis Traefik tetap terpasang di namespace `traefik`.

## Tugas

1. **Part A — Inspeksi Skema CRD & Uji Validasi `ConfigForge`:**
   - Periksa status CRD `configforges.lab.example.com` (`kubectl get crd configforges.lab.example.com`) dan pastikan kondisinya `Established=True`.
   - Gunakan `kubectl explain configforge.spec` untuk memeriksa dokumentasi skema OpenAPI v3 pada field `spec.data` beserta batas panjang karakternya (`maxLength: 40`).
   - Buktikan bahwa validasi skema OpenAPI v3 bekerja dengan mencoba menerapkan objek `ConfigForge` yang **tidak valid** (misalnya memiliki `spec.data` lebih dari `40` karakter) dan amati bahwa API server **menolak** objek tersebut.
   - Buat sebuah objek `ConfigForge` yang **valid** (`apiVersion: lab.example.com/v1`, `kind: ConfigForge`) bernama `app-cfg` di namespace `cka-lab16` dengan `spec.data` yang tidak melebihi `40` karakter (misalnya `"mode=production"`), lalu pastikan objek tersebut tersimpan dan dapat dibaca dengan `kubectl -n cka-lab16 get cfgforge app-cfg`.

2. **Part B — Buat Custom Resource `IngressRoute` dan Buktikan Rekonsiliasi Traefik:**
   - Pastikan CRD `ingressroutes.traefik.io` telah tersedia dan `Deployment` `traefik` di namespace `traefik` berstatus `Available`.
   - Buat sebuah *Custom Resource* `IngressRoute` (`apiVersion: traefik.io/v1alpha1`, `kind: IngressRoute`) bernama `app-route` di namespace `cka-lab16` yang:
     - Menggunakan `entryPoints: ["web"]`.
     - Memiliki aturan rute (`spec.routes`) dengan `kind: Rule` dan `match: Host(\`app.lab16.local\`)`.
     - Meneruskan trafik ke `services` bernama `web` pada `port: 80`.
   - Buktikan bahwa operator Traefik merekonsiliasi `IngressRoute` tersebut dengan mengirim permintaan HTTP ke NodePort `30082` menggunakan header `Host: app.lab16.local`:
     `curl -s -H 'Host: app.lab16.local' http://localhost:30082/`
     Pastikan respons mengembalikan halaman sambutan nginx (`Welcome to nginx!`).

3. **Part B (Lanjutan) — Uji Penghapusan Rute pada Reconciler & Kembalikan State Akhir:**
   - Hapus `IngressRoute` `app-route` (`kubectl -n cka-lab16 delete ingressroute app-route`) dan buktikan bahwa permintaan `curl -i -H 'Host: app.lab16.local' http://localhost:30082/` kini mengembalikan `404 page not found` karena Traefik telah menghapus rute tersebut dari konfigurasi aktifnya.
   - Terapkan kembali (`kubectl apply`) `IngressRoute` `app-route` di namespace `cka-lab16` dan pastikan `curl -s -H 'Host: app.lab16.local' http://localhost:30082/` kembali mengembalikan halaman sambutan nginx sebelum menjalankan `verify/verify.sh`.
