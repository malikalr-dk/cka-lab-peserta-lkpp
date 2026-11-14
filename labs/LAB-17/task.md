# LAB-17 — Manajemen Komponen Kluster dengan Kustomize dan Helm

Tujuan: merender dan menerapkan *overlay* multi-lingkungan (`dev` dan `prod`) menggunakan `kubectl kustomize` / `kubectl apply -k`, mengelola siklus hidup rilis paket aplikasi menggunakan `helm` (`install`, `upgrade`, `rollback`), serta mencatat state akhir ke laporan verifikasi.

## Konteks & State Awal

- Seluruh direktori kerja latihan telah disiapkan oleh skrip starter di node control-plane pada `/root/lab17/`:
  - `/root/lab17/base/`: konfigurasi dasar Kustomize (`kustomization.yaml`, `configmap.yaml`, `deployment.yaml`, `service.yaml`) yang menjalankan `nginx:1.27-alpine` dengan `imagePullPolicy: IfNotPresent`.
  - `/root/lab17/overlays/dev/`: *overlay* pengembangan dengan `namespace: lab17`, `namePrefix: dev-`, dan label `env: dev`.
  - `/root/lab17/overlays/prod/`: *overlay* produksi dengan `namespace: lab17-prod`, `namePrefix: prod-`, label `env: prod`, serta *patch* `patch-replicas-limits.yaml` yang mengubah jumlah replika menjadi `3` dan menambahkan `resources.limits` (`cpu: 200m`, `memory: 128Mi`).
  - `/root/lab17/chart/lab17-web/`: Helm chart lokal (`Chart.yaml`, `values.yaml`, `templates/deployment.yaml`, `templates/service.yaml`) yang mendeploy `nginx:1.27-alpine` (`IfNotPresent`) dengan nilai awal `replicaCount: 1`.
- Namespace `lab17` dan `lab17-prod` telah disiapkan dalam keadaan kosong, sementara namespace `lab17-helm` belum dibuat agar dibuat otomatis melalui flag `--create-namespace` pada `helm install`.
- Lingkungan kluster menggunakan Kubernetes `v1.37.2` dan Helm `v4.3.2` tanpa akses repositori eksternal.

## Tugas

Bekerjalah dari direktori `/root/lab17/` di node control-plane:

### Bagian A — Kustomize (`base` & `overlays`)

1. **Inspeksi dan Render Tanpa Apply:**
   - Periksa isi `/root/lab17/base/`, `/root/lab17/overlays/dev/`, dan `/root/lab17/overlays/prod/`.
   - Render kedua *overlay* ke terminal tanpa menerapkannya ke kluster menggunakan:
     - `kubectl kustomize /root/lab17/overlays/dev`
     - `kubectl kustomize /root/lab17/overlays/prod`

2. **Terapkan Overlay `dev` ke Namespace `lab17`:**
   - Terapkan hasil Kustomize *overlay* `dev`:
     `kubectl apply -k /root/lab17/overlays/dev`

3. **Terapkan Overlay `prod` ke Namespace `lab17-prod`:**
   - Terapkan hasil Kustomize *overlay* `prod`:
     `kubectl apply -k /root/lab17/overlays/prod`

4. **Verifikasi Perbedaan Antar-Overlay:**
   - Pastikan objek di namespace `lab17` memiliki awalan nama `dev-` (`Deployment/dev-web`), `1` replika *Ready*, label `env: dev`, dan tanpa `resources.limits`.
   - Pastikan objek di namespace `lab17-prod` memiliki awalan nama `prod-` (`Deployment/prod-web`), `3` replika *Ready*, serta memiliki `resources.limits` (`cpu: 200m`, `memory: 128Mi`) dari *patch*.

### Bagian B — Helm (`install`, `upgrade`, `rollback`)

5. **Instal Rilis Helm Lokal (`lab17-web`):**
   - Instal chart lokal `/root/lab17/chart/lab17-web` sebagai rilis `lab17-web` di namespace `lab17-helm`:
     `helm install lab17-web /root/lab17/chart/lab17-web -n lab17-helm --create-namespace`

6. **Upgrade Rilis ke 2 Replika:**
   - Lakukan *upgrade* rilis `lab17-web` dengan mengubah `replicaCount=2`:
     `helm upgrade lab17-web /root/lab17/chart/lab17-web -n lab17-helm --set replicaCount=2`

7. **Rollback Lalu Upgrade Kembali:**
   - Lakukan *rollback* rilis `lab17-web` kembali ke revisi `1`:
     `helm rollback lab17-web 1 -n lab17-helm`
   - Selanjutnya lakukan `helm upgrade` kembali dengan `--set replicaCount=2` sehingga rilis berakhir dengan `2` replika aktif (dan nomor revisi bertambah di `helm history lab17-web -n lab17-helm`).

8. **Tulis File Laporan `/root/lab17/report.txt`:**
   - Buat file `/root/lab17/report.txt` yang berisi tepat dua baris berikut sesuai kondisi aktual di kluster:
     ```text
     kustomize_prod_replicas=<n>
     helm_revision=<n>
     ```

## Apa yang Diverifikasi

1. `Deployment/dev-web` di namespace `lab17` berstatus *available* dengan `1` replika *Ready* dan label `env=dev`.
2. `Deployment/prod-web` di namespace `lab17-prod` memiliki `3` replika *Ready*.
3. `Deployment/prod-web` memiliki `resources.limits.cpu` hasil *patch*, sedangkan `Deployment/dev-web` tidak memiliki `resources.limits.cpu`.
4. Rilis Helm `lab17-web` di namespace `lab17-helm` berstatus `STATUS: deployed` dengan `REVISION >= 2`.
5. `Deployment/lab17-web` yang dikelola Helm di namespace `lab17-helm` memiliki `2` replika (`spec.replicas=2` dan `readyReplicas=2`).
6. File `/root/lab17/report.txt` memuat kedua kunci (`kustomize_prod_replicas` dan `helm_revision`) dengan nilai tidak kosong dan nilai `kustomize_prod_replicas` cocok dengan jumlah replika `prod-web` di kluster (`3`).

## Batasan

- Jangan menjalankan `helm repo add` atau mengunduh chart/image dari internet; chart dan image sudah tersedia lokal.
- Gunakan hanya image lokal yang sudah tersedia di cache containerd (`nginx:1.27-alpine` dengan `imagePullPolicy: IfNotPresent`).
- Jangan menggunakan chart `/opt/lab/charts/kube-prometheus-stack-93.3.0.tgz` (image tidak di-cache) dan jangan mengubah rilis `traefik` di namespace `traefik`.
