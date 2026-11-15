# Expected Result — LAB-16

1. **Deployment `portal` kembali 2 replika dan Ready:**
   - `kubectl -n cka-lab16 get deployment portal` → `spec.replicas=2`, `READY 2/2`.

2. **Service `portal` punya dua endpoint:**
   - `kubectl -n cka-lab16 get endpoints portal` → dua alamat IP.

3. **Ingress menunjuk port yang benar:**
   - `portal-ingress` backend `portal:80` (bukan `8080`).

4. **Layanan melayani HTTP:**
   - `curl -s -o /dev/null -w '%{http_code}' -H 'Host: portal.lab.local' http://localhost:30081/` → `200`.

5. **Data di PVC tersaji:**
   - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt` → `lab16-proof`.

6. **Laporan insiden lengkap:**
   - `/root/lab/lab16-report.txt` memuat `incident`, `root_cause`, `action` (tidak kosong) dan `proof=200`.

7. **Output verifier:**
   - `bash verify/verify.sh` mencetak enam baris `PASS:` dan diakhiri `RESULT: PASS (6/6)` dengan exit `0`.
