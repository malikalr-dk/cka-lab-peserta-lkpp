# LAB-19 — Gateway API dengan Traefik (`GatewayClass`, `Gateway`, dan `HTTPRoute`)

Tujuan: ekspos HTTP lewat Gateway API + Traefik; perbaiki `broken-route` sampai dua hostname nginx lolos di NodePort.

## Konteks & State Awal

- Starter sudah terapkan CRD Gateway API v1.7.0 dari `/opt/lab/manifests/gateway-api.yaml` dan mengaktifkan provider Gateway API pada rilis Helm **Traefik** di namespace `traefik` (dari chart lokal `/opt/lab/charts/traefik-42.4.0.tgz`).
- Service Traefik di namespace `traefik` bertipe `NodePort` dan mendengarkan trafik HTTP pada port `80` (NodePort `30081`, dapat diperiksa dengan `kubectl -n traefik get svc traefik`).
- Objek `GatewayClass` bernama `traefik` sudah tersedia di kluster (`kubectl get gatewayclass`).
- Namespace `cka-lab19` sudah disiapkan starter dan berisi:
  - `Deployment` bernama `web` (`nginx:1.27-alpine`, `2` replika, `imagePullPolicy: IfNotPresent`).
  - `Service` bernama `web` pada port `80`.
  - Sebuah `HTTPRoute` bernama `broken-route` untuk hostname `broken.gw.local` yang menargetkan parent `Gateway` `web-gateway`, namun memiliki kesalahan konfigurasi pada bagian `backendRefs`.

## Tugas

1. **Bikin `Gateway` `web-gateway`:**
   - Di dalam namespace `cka-lab19`, buat sebuah `Gateway` (`apiVersion: gateway.networking.k8s.io/v1`) bernama `web-gateway` dengan spesifikasi:
     - `gatewayClassName: traefik`
     - Satu *listener* bernama `http` dengan protokol `HTTP` pada port `80` yang mengizinkan rute dari namespace yang sama (`allowedRoutes.namespaces.from: Same`).
   - Periksa `kubectl -n cka-lab19 describe gateway web-gateway` hingga kondisi `Accepted` bernilai `True` dan `status.addresses` terisi.

2. **Bikin `HTTPRoute` `web-route`:**
   - Di dalam namespace `cka-lab19`, buat sebuah `HTTPRoute` (`apiVersion: gateway.networking.k8s.io/v1`) bernama `web-route` yang:
     - Menunjuk ke parent `Gateway` `web-gateway` (`parentRefs`).
     - Melayani hostname `web.gw.local` (`hostnames: ["web.gw.local"]`).
     - Mengarahkan path prefix `/` (`PathPrefix: /`) ke backend `Service` `web` pada port `80`.
   - Uji akses HTTP melalui NodePort Traefik (`30081`):
     `curl -s -H 'Host: web.gw.local' http://localhost:30081/`

3. **Diagnosis dan perbaiki `broken-route`:**
   - Periksa konfigurasi `HTTPRoute` `broken-route` dan `Service` `web` di namespace `cka-lab19`:
     `kubectl -n cka-lab19 get httproute broken-route -o yaml`
     `kubectl -n cka-lab19 get svc web`
   - Perbaiki kesalahan port pada `backendRefs` di `broken-route` agar mengarah ke port `80` milik `Service` `web`.
   - Buktikan bahwa kedua hostname (`web.gw.local` dan `broken.gw.local`) kini mengembalikan halaman sambutan nginx (`Welcome to nginx!`) saat diakses melalui NodePort Traefik:
     `curl -s -H 'Host: broken.gw.local' http://localhost:30081/`