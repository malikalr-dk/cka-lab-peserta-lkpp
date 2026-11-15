# LAB-14 — Helm Release dan Cluster Monitoring

Tujuan: kelola satu rilis Helm sampai naik-turun revisi, lalu buktikan Prometheus dan Grafana benar-benar jalan.

Cakupan domain CKA: Cluster Architecture, Installation & Configuration (25%), butir "Use Helm"; Troubleshooting (30%), butir "Monitor cluster and application resource usage".

## Konteks & State Awal

- Chart lokal `lab17-web` ada di `/root/lab17/chart/lab17-web` (nginx, 1 replika, Service ClusterIP).
- Namespace `gisp-app` sudah ada dan kosong.
- Prometheus + Grafana sudah dipasang trainer di namespace `lab-monitoring` (rilis `kube-prometheus`), dari chart lokal. Kamu tidak perlu memasang ulang.
- Tidak ada unduhan internet: chart dan image sudah di node.

## Tugas

1. **Pasang rilis pertama:**
   - `helm install lab17-web /root/lab17/chart/lab17-web -n gisp-app`
   - `kubectl -n gisp-app get deploy,svc`
   - `helm -n gisp-app status lab17-web`

2. **Naikkan replika lewat upgrade:**
   - `helm upgrade lab17-web /root/lab17/chart/lab17-web -n gisp-app --set replicaCount=2`
   - `kubectl -n gisp-app get deploy lab17-web` → `2/2`

3. **Rollback lalu upgrade lagi (revisi harus bertambah):**
   - `helm rollback lab17-web 1 -n gisp-app`
   - `helm upgrade lab17-web /root/lab17/chart/lab17-web -n gisp-app --set replicaCount=2`
   - `helm -n gisp-app history lab17-web` → REVISION minimal 2, status terakhir `deployed`

4. **Baca monitoring:**
   - `kubectl -n lab-monitoring get pods` → Prometheus dan Grafana `Running`
   - `kubectl top nodes` dan `kubectl -n gisp-app top pods` → angka keluar (metrics-server ikut melayani)
   - Buka Grafana hanya kalau trainer menunjukkan caranya; yang dinilai adalah Prometheus/Grafana hidup, bukan dashboard yang kamu buat.

5. **Tulis laporan** di `/root/lab17/report.txt`, tepat dua baris:

   ```text
   helm_revision=<nomor revisi terakhir dari helm history>
   prometheus_ready=yes
   ```

6. **Jalankan verifier:** `bash verify/verify.sh` → `RESULT: PASS (6/6)`.

## Batasan

- Jangan `helm uninstall` di tengah langkah; rilis harus berakhir `deployed`.
- Jangan mengubah objek hasil Helm dengan `kubectl edit` atau `kubectl set`: perubahan itu hilang pada upgrade berikutnya dan tidak dinilai.
- Jangan menghapus namespace `lab-monitoring`; itu milik sesi ini.
- Tag image tetap `1.27-alpine`, jangan pakai `latest`.
