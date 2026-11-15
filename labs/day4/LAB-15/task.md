# LAB-15 — Integrated Incident Investigation

Tujuan: pulihkan Portal GISP yang mati karena dua gangguan sekaligus, lalu buktikan lewat HTTP.

Cakupan domain CKA: Troubleshooting (30%), Services & Networking (20%).

## Konteks & State Awal

- Cluster `cka-pN` sudah punya Traefik sebagai Ingress controller di NodePort `30081` dan StorageClass `local-path`.
- Namespace `cka-lab15` sudah berisi aplikasi `portal` yang tidak bisa diakses. Ada dua gangguan yang tidak saling bergantung.
- Pemeriksaan cepat: `curl -H 'Host: portal.lab.local' http://localhost:30081/` gagal, padahal Pod-nya `Running`.

## Batasan

- **DILARANG** menghapus namespace atau membangun ulang Deployment dari nol. Perbaiki yang ada.
- Jangan mengubah image, jumlah replika, mount PVC, atau nama objek. Yang dinilai: jalur trafik sampai aplikasi.
- Jangan menyentuh `kube-system` atau namespace `traefik`.

## Tugas

1. **Kumpulkan bukti kondisi awal:**
   - `kubectl -n cka-lab15 get deploy,svc,ingress,pods -o wide`
   - `kubectl -n cka-lab15 describe svc portal`
   - `kubectl -n cka-lab15 describe ingress portal-ingress`
   - `curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: portal.lab.local' http://localhost:30081/`

2. **Cari gangguan pertama (lapisan Service):**
   - Bandingkan label Pod dengan selector Service. `kubectl -n cka-lab15 get pods --show-labels`.
   - Perbaiki supaya Service memilih Pod yang benar. Bukti: `kubectl -n cka-lab15 get endpoints portal` menampilkan dua alamat.

3. **Cari gangguan kedua (lapisan Ingress):**
   - Periksa backend yang dirujuk `portal-ingress` dan bandingkan dengan Service yang benar-benar ada.
   - Arahkan backend ke Service `portal` port `80`.

4. **Buktikan hasilnya:**
   - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/ | head -3` → halaman nginx, HTTP `200`.
   - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt` → `lab15-proof`.

5. **Jalankan verifier:** `bash verify/verify.sh` → `RESULT: PASS (6/6)`.

## Yang dinilai

Deployment 2/2 Ready, Service `portal` memilih Pod yang benar dengan 2 endpoint, Ingress `portal-ingress` mengarah ke `portal:80`, ConfigMap `app-config` masih dipakai, HTTP `200` untuk host `portal.lab.local`, dan `/data/proof.txt` berisi `lab15-proof`.
