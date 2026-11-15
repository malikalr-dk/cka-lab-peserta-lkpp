# LAB-21 — Kustomize: Base dan Overlay dev/prod

Tujuan: pakai satu base untuk dua environment, bedakan lewat overlay, lalu buktikan hasilnya di cluster.

Cakupan domain CKA: Cluster Architecture, Installation & Configuration (25%), butir "Use Helm and Kustomize".

## Konteks & State Awal

- Tree Kustomize sudah ada di `/root/lab21`: `base/`, `overlays/dev/`, `overlays/prod/`.
- Namespace `lab21` dan `lab21-prod` sudah dibuat kosong.
- Image `nginx:1.27-alpine` sudah ada di golden image.

## Tugas

1. **Lihat hasil render sebelum apply:**
   - `kubectl kustomize /root/lab21/overlays/dev`
   - `kubectl kustomize /root/lab21/overlays/prod`
   - Perhatikan perbedaan `replicas`, `limits`, `namePrefix`, dan label `env`.

2. **Terapkan kedua overlay:**
   - `kubectl apply -k /root/lab21/overlays/dev`
   - `kubectl apply -k /root/lab21/overlays/prod`

3. **Buktikan hasilnya:**
   - `kubectl -n lab21 get deploy dev-web -o wide` → `1/1`, label `env=dev`
   - `kubectl -n lab21-prod get deploy prod-web -o wide` → `3/3`, label `env=prod`
   - `kubectl -n lab21-prod get deploy prod-web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}'` → `200m`
   - `kubectl -n lab21 get deploy dev-web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}'` → kosong

4. **Tulis laporan** di `/root/lab21/report.txt`:

   ```text
   kustomize_prod_replicas=3
   ```

5. **Jalankan verifier:** `bash verify/verify.sh` → `RESULT: PASS (5/5)`.

## Batasan

- Jangan mengubah isi `base/`. Perbedaan environment harus datang dari overlay.
- Jangan memakai `kubectl set` atau edit langsung objek hasil apply; nilai yang dinilai adalah hasil `apply -k`.
