# LAB-14 — HorizontalPodAutoscaler (HPA) dengan metrics-server

## Tujuan

Mengonfigurasi *HorizontalPodAutoscaler* (`HPA`) pada sebuah `Deployment` berdasarkan utilisasi CPU
dari `metrics-server`, membuktikan **scale-out** nyata di bawah beban HTTP sintetis, lalu membuktikan
**scale-in** setelah beban dihentikan.

## Konteks & State Awal

- Skrip starter sudah memasang `metrics-server` di namespace `kube-system` dari
  `/opt/lab/manifests/metrics-server.yaml` (flag `--kubelet-insecure-tls` untuk sertifikat kubelet
  `kubeadm`) dan memastikan `kubectl top nodes` serta `kubectl -n cka-lab14 top pods` sudah merespons.
- Namespace `cka-lab14` sudah disiapkan starter beserta:
  - `Deployment` bernama `demo` (`docker.io/stefanprodan/podinfo:6.7.1`, `1` replika,
    `containerPort: 9898`, `resources.requests.cpu: 100m`, `imagePullPolicy: IfNotPresent`).
  - `Service` bernama `demo` bertipe `ClusterIP` pada port `9898` → `9898`, selector `app: demo`.
- **Penting:** HPA hanya bisa menghitung persentase utilisasi kalau Pod target punya
  `resources.requests.cpu`. Jangan menghapus atau mengubah `requests.cpu: 100m` pada `Deployment`
  `demo` — angka itulah penyebut perhitungannya.
- Generator beban dijalankan sebagai Pod dengan `--restart=Never` (bukan sesi interaktif) agar tidak
  menggantung pada sesi non-TTY.

## Tugas

### 1. Verifikasi Metrics API & buat HorizontalPodAutoscaler `demo`

- Pastikan metrik Pod terbaca di namespace ini:

  ```bash
  kubectl -n cka-lab14 top pods
  ```

- Buat `HorizontalPodAutoscaler` bernama `demo` yang menargetkan `Deployment/demo`:

  ```bash
  kubectl -n cka-lab14 autoscale deployment demo --cpu=50% --min=1 --max=4
  ```

  Parameter yang dinilai: `minReplicas: 1`, `maxReplicas: 4`, target utilisasi CPU rata-rata `50%`.

### 2. Picu Scale-Out dengan Beban Trafik Sintetis

- Jalankan Pod generator beban `load-generator` (`busybox:1.37`, `--restart=Never`) yang menembak
  `Service` `demo` dengan **4 loop `wget` paralel**:

  ```bash
  kubectl -n cka-lab14 run load-generator \
    --image=busybox:1.37 \
    --image-pull-policy=IfNotPresent \
    --restart=Never \
    --command -- sh -c 'for i in 1 2 3 4; do (while true; do wget -q -O- http://demo.cka-lab14.svc.cluster.local:9898/ >/dev/null 2>&1; done) & done; wait'
  ```

- Satu loop `wget` berurutan hanya membakar sekitar `68m` dari `requests.cpu: 100m` — terlalu dekat
  dengan ambang `50%`, sehingga HPA berayun `1 ↔ 2` dan scale-out tidak pernah stabil. Empat loop
  paralel menghasilkan sekitar `110–130m` (≈ `110–130%`).
- Pantau perkembangan replika selama kurang lebih `45–120` detik:

  ```bash
  kubectl -n cka-lab14 get hpa demo
  kubectl -n cka-lab14 get deploy demo
  ```

  Scale-out dianggap tercapai saat `READY`/`readyReplicas` pada `Deployment` `demo` menjadi `> 1`.

### 3. Perpendek Jendela Scale-Down, Hentikan Beban, Amati Scale-In

- Jendela stabilisasi scale-down default adalah `300` detik, terlalu lama untuk latihan dan untuk
  verifier. **Wajib** perpendek lebih dulu:

  ```bash
  kubectl -n cka-lab14 patch hpa demo --type='merge' \
    -p '{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds":10}}}}'
  ```

- Setelah scale-out terbukti (tercatat pada `status.lastScaleTime` dan event `SuccessfulRescale`),
  hapus Pod generator beban:

  ```bash
  kubectl -n cka-lab14 delete pod load-generator --wait=false
  ```

- Pantau penurunan utilisasi CPU pada HPA hingga di bawah `50%` dan replika menyusut kembali ke
  batas minimum (`1`):

  ```bash
  kubectl -n cka-lab14 get hpa demo -w
  ```

## Apa yang Diverifikasi

```bash
bash labs/LAB-14/verify/verify.sh
```

Verifier mencetak satu baris `PASS:`/`FAIL:` per assertion dan diakhiri `RESULT: PASS (5/5)` atau
`RESULT: FAIL (n/5)`. Lima assertion, semuanya berbasis perilaku:

1. **Metrics API merespons** — `kubectl top nodes` atau `kubectl -n cka-lab14 top pods` mengembalikan
   baris metrik (retry berbatas 60 detik).
2. **`Deployment` `demo` Ready** dan container-nya punya `resources.requests.cpu` terisi (nilainya
   tidak dikunci, field-nya wajib ada).
3. **`HorizontalPodAutoscaler` `demo`** ada, menargetkan `Deployment/demo`, `minReplicas: 1`,
   `maxReplicas: 4`, target CPU rata-rata `50%`.
4. **Scale-out:** di bawah beban 4 loop `wget` paralel yang dijalankan verifier sendiri
   (`lab14-verify-load`), `status.readyReplicas` pada `Deployment` `demo` menjadi `> 1` dalam jendela
   **180 detik**.
5. **Scale-in:** setelah verifier menghapus Pod beban (`lab14-verify-load` **dan** `load-generator`
   milik Anda, kalau masih ada), `readyReplicas` kembali ke `1` dalam jendela **120 detik**. Jendela
   ini hanya tercapai kalau `behavior.scaleDown.stabilizationWindowSeconds: 10` sudah dipasang pada
   langkah 3.

Verifier tidak mengunci nama image — image hanya dicetak sebagai `INFO`. Pod `load-generator` milik
Anda tidak wajib dihapus sebelum verifikasi; verifier menghapusnya sendiri pada assertion scale-in.

## Batasan

- Semua langkah dikerjakan dengan `kubectl`. Tidak ada dashboard, `k9s`, atau editor GUI.
- Jangan mengubah `metrics-server` di `kube-system`, jangan menambah `--kubelet-insecure-tls` ulang,
  dan jangan menyentuh Pod `kube-system` lain.
- Jangan menghapus `resources.requests.cpu` dari `Deployment` `demo`; tanpa field itu HPA tidak bisa
  menghitung persentase dan assertion 2 gagal.
- `minReplicas`/`maxReplicas`/target CPU harus tepat `1`/`4`/`50%` — HPA dengan nilai lain dinilai
  salah walaupun scaling-nya berjalan.
- Node tidak punya akses registry: jangan mengubah image `Deployment` ke tag yang tidak ada di cache
  node, karena Pod akan `ImagePullBackOff` dan lab tidak bisa dilanjutkan.
- Generator beban harus Pod `--restart=Never`; `kubectl run -it`/`exec` interaktif menggantung pada
  sesi non-TTY.

## Memakai Image Sendiri (BYO)

Image aplikasi internal boleh dipakai sebagai pengganti `podinfo` — verifier menilai **perilaku**
(HPA menargetkan Deployment, `requests.cpu` ada, replika naik saat dibebani lalu turun saat beban
hilang), bukan nama image.

**Format deklarasi** di node control-plane, sebelum starter dijalankan:

```text
/root/lab/lab14-image.txt
image=<registry>/<nama>:<tag>
port=<port>
path=<endpoint yang dibebani>
```

Kalau file ini tidak ada, starter memakai `docker.io/stefanprodan/podinfo:6.7.1`, port `9898`, path `/`.

Syarat:

1. **Tag ter-pin, bukan `latest`.** Starter menolak image tanpa tag atau `:latest` dengan pesan
   `(expected: <registry>/<name>:<tag> with a pinned version, e.g. :1.2.3)`.
2. **Port valid `1–65535`.** Starter menolak `port=` yang bukan angka atau di luar rentang dengan
   pesan `(expected: 1-65535)`.
3. Aplikasi listen HTTP pada `port=` yang dideklarasikan; `Service` `demo` memakai port yang sama.
4. **Image sudah di-import ke cache node H-1 oleh trainer** — node tidak punya akses registry saat
   kelas, jadi import dilakukan sebelum kelas berjalan (prosedur di `docs/lab-images.md`).
5. **Endpoint di `path=` harus membakar CPU.** Kalau `path=` menunjuk endpoint murah (mis. `/healthz`
   yang hanya mengembalikan `200 OK`), utilisasi tidak akan melewati `50%` walaupun 4 loop berjalan,
   dan assertion scale-out gagal. Pilih endpoint yang melakukan kerja nyata (query, render, hitung) —
   untuk `podinfo` cukup `/`.
6. Kalau aplikasi Anda butuh `requests.cpu` berbeda dari `100m`, sesuaikan Deployment **dan** ambang
   HPA tetap `50%`; verifier tidak mengunci nilai request, hanya mewajibkan field itu terisi.

Contoh:

```bash
mkdir -p /root/lab
cat > /root/lab/lab14-image.txt <<'EOF'
image=registry.internal/portal-api:1.4.2
port=8080
path=/api/report
EOF
bash labs/LAB-14/starter/setup.sh
```
