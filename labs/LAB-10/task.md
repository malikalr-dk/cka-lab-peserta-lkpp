# LAB-10 — Ingress dengan Traefik dan Troubleshooting Jaringan

Tujuan: mengekspos layanan HTTP menggunakan resource `Ingress` melalui *Ingress Controller* Traefik serta mendiagnosis dan memperbaiki `Ingress` yang gagal meneruskan trafik menggunakan hasil inspeksi kluster (`kubectl describe ingress`, daftar `Service`/`Endpoints`, dan log Traefik).

## Konteks & State Awal

- Skrip starter telah memasang **Traefik** di namespace `traefik` dari chart lokal `/opt/lab/charts/traefik-42.4.0.tgz` dengan `Service` bertipe `NodePort` yang mendengarkan trafik HTTP pada **NodePort `30081`** (`http://localhost:30081/`).
- Namespace `cka-lab10` telah disiapkan oleh starter dan berisi:
  - `Deployment` bernama `app` (`nginx:1.27-alpine`, `2` replika, `imagePullPolicy: IfNotPresent`).
  - `Service` bernama `app` pada port `80`.
  - Sebuah `Ingress` bernama `broken-ingress` untuk host `broken.lab.local` yang saat ini mengalami gangguan (mengembalikan error saat diakses).

## Tugas

1. **Buat Ingress Baru (`app-ingress`):**
   - Di dalam namespace `cka-lab10`, buat sebuah `Ingress` bernama `app-ingress` (`ingressClassName: traefik`) dengan aturan:
     - Host: `app.lab.local`
     - Path: `/` (`pathType: Prefix`)
     - Backend: `Service` `app` pada port `80`
   - Buktikan dari node (`cka-pN-cp`) bahwa permintaan HTTP berikut mengembalikan halaman sambutan nginx (`HTTP 200`):
     `curl -s -H 'Host: app.lab.local' http://localhost:30081/`

2. **Troubleshooting & Perbaikan `broken-ingress`:**
   - Uji akses awal ke `broken.lab.local`:
     `curl -i -s -H 'Host: broken.lab.local' http://localhost:30081/`
   - **Penting:** Jangan menebak-nebak penyebabnya. Temukan letak kesalahan konfigurasi dengan memeriksa:
     - `kubectl -n cka-lab10 describe ingress broken-ingress`
     - `kubectl -n cka-lab10 get svc,endpoints`
     - `kubectl -n traefik logs -l app.kubernetes.io/name=traefik`
   - Perbaiki objek `Ingress` `broken-ingress` di namespace `cka-lab10` agar mengarah ke backend `Service` dan port yang benar di `cka-lab10`.
   - Buktikan setelah perbaikan bahwa perintah berikut mengembalikan respons `HTTP 200` (halaman sambutan nginx):
     `curl -s -H 'Host: broken.lab.local' http://localhost:30081/`
