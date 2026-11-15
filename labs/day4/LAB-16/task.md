# LAB-16 — Final Recovery, Verification & Report

Tujuan: pulihkan layanan sampai bisa diakses lewat HTTP, lalu serahkan laporan insiden berisi bukti.

Cakupan domain CKA: Troubleshooting (30%), Workloads & Scheduling (15%), Services & Networking (20%).

## Konteks & State Awal

- Namespace `gisp-app` berisi aplikasi `portal` yang tidak melayani trafik. Dua hal rusak: jumlah replika Deployment dan port pada Ingress.
- Namespace, ConfigMap, PVC, dan Service sudah ada. Jangan membuat ulang dari nol.
- Pemeriksaan awal: `kubectl -n gisp-app get deploy,svc,ingress,pods` dan `curl -H 'Host: portal.lab.local' http://localhost:30081/`.

## Batasan

- **DILARANG** `kubeadm reset`, menghapus namespace, atau mengganti nama objek.
- Jangan mengubah image (`nginx:1.27-alpine`) dan jangan menghapus PVC `portal-data`.
- Penilaian individual: kerjakan sendiri, 75 menit, tanpa kunci jawaban.
- Jangan menyentuh `kube-system` atau namespace `traefik`.

## Tugas

1. **Baseline:** catat kondisi awal Deployment, Service, Ingress, dan hasil `curl`.
2. **Perbaiki layanan:**
   - Kembalikan jumlah replika Deployment `portal` menjadi `2` dan pastikan keduanya `Ready`.
   - Arahkan backend Ingress `portal-ingress` ke Service `portal` port `80`.
3. **Buktikan lewat trafik, bukan lewat status objek:**
   - `curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: portal.lab.local' http://localhost:30081/` → `200`.
   - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt` → `lab16-proof`.
4. **Tulis laporan** di `/root/lab/lab16-report.txt`, tepat empat baris:

   ```text
   incident=<nama atau nomor insiden>
   root_cause=<penyebab teknis, satu kalimat>
   action=<perbaikan yang dilakukan>
   proof=200
   ```

5. **Jalankan verifier:** `bash verify/verify.sh` → `RESULT: PASS (6/6)`.

## Yang dinilai

Deployment `2/2 Ready`, Service dengan 2 endpoint, Ingress `portal:80`, HTTP `200`, berkas PVC tersaji lewat HTTP, dan laporan dengan empat kunci terisi serta `proof=200`.
