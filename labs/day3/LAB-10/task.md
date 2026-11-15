# LAB-10 — Ingress dengan Traefik dan Troubleshooting Jaringan

Tujuan: ekspos HTTP lewat `Ingress` Traefik dan perbaiki `broken-ingress` dengan inspeksi kluster (describe, Service/Endpoints, log Traefik).

## Konteks & State Awal

- Starter sudah pasang **Traefik** di namespace `traefik` dari chart lokal `/opt/lab/charts/traefik-42.4.0.tgz`; `Service` `NodePort` HTTP di **NodePort `30081`** (`http://localhost:30081/`).
- Starter sudah siapkan namespace `gisp-app` berisi:
  - `Deployment` `app` (`nginx:1.27-alpine`, `2` replika, `imagePullPolicy: IfNotPresent`).
  - `Service` `app` port `80`.
  - `Ingress` `broken-ingress` host `broken.lab.local` yang rusak (error saat diakses).

## Tugas

1. **Buat Ingress baru (`app-ingress`):**
   - Di `gisp-app`, buat `Ingress` `app-ingress` (`ingressClassName: traefik`) dengan:
     - Host: `app.lab.local`
     - Path: `/` (`pathType: Prefix`)
     - Backend: `Service` `app` port `80`
   - Buktikan dari node (`cka-pN-cp`) bahwa perintah ini mengembalikan halaman nginx (`HTTP 200`):
     `curl -s -H 'Host: app.lab.local' http://localhost:30081/`

2. **Troubleshooting & perbaiki `broken-ingress`:**
   - Uji akses awal:
     `curl -i -s -H 'Host: broken.lab.local' http://localhost:30081/`
   - **Penting:** Jangan tebak-tebakan. Cari salah konfigurasi lewat:
     - `kubectl -n gisp-app describe ingress broken-ingress`
     - `kubectl -n gisp-app get svc,endpoints`
     - `kubectl -n traefik logs -l app.kubernetes.io/name=traefik`
   - Perbaiki `Ingress` `broken-ingress` di `gisp-app` agar mengarah ke `Service` dan port yang benar.
   - Setelah perbaikan, perintah ini harus balas `HTTP 200` (halaman nginx):
     `curl -s -H 'Host: broken.lab.local' http://localhost:30081/`