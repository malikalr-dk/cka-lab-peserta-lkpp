# Expected Result — LAB-21

1. **Overlay dev terpasang:**
   - `lab21/dev-web` ada, `1/1` Ready, label `env=dev`, tanpa `resources.limits`.

2. **Overlay prod terpasang:**
   - `lab21-prod/prod-web` ada, `3/3` Ready, label `env=prod`, `limits.cpu=200m`.

3. **Namespace dari overlay dipakai:**
   - `lab21/dev-web-config` dan `lab21-prod/prod-web-config` ada (hasil `namePrefix` + `namespace`).

4. **Laporan terisi:**
   - `/root/lab21/report.txt` memuat `kustomize_prod_replicas=3` dan cocok dengan replika `prod-web` yang hidup.

5. **Output verifier:**
   - `bash verify/verify.sh` mencetak lima baris `PASS:` dan diakhiri `RESULT: PASS (5/5)` dengan exit `0`.
