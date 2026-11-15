# Expected Result — LAB-15

Semua perintah dijalankan di node control-plane peserta.

1. **Deployment `portal` sehat:**
   - `kubectl -n gisp-app get deployment portal` → `READY 2/2`, image `nginx:1.27-alpine`.

2. **Service `portal` memilih Pod yang benar:**
   - `kubectl -n gisp-app get svc portal -o jsonpath='{.spec.selector.app}'` → `portal-app`.
   - `kubectl -n gisp-app get endpoints portal` → dua alamat IP.

3. **Ingress `portal-ingress` menunjuk Service yang ada:**
   - host `portal.lab.local`, backend `portal` port `80`.

4. **Trafik sampai aplikasi:**
   - `curl -s -o /dev/null -w '%{http_code}' -H 'Host: portal.lab.local' http://localhost:30081/` → `200`.

5. **Berkas di PVC tersaji:**
   - `curl -s -H 'Host: portal.lab.local' http://localhost:30081/data/proof.txt` → `lab15-proof`.

6. **Konfigurasi tidak dirusak:**
   - ConfigMap `app-config` tetap ada dengan `GREETING=halo-lab15` dan tetap dipakai Deployment lewat `envFrom`.

7. **Output verifier:**
   - `bash verify/verify.sh` mencetak enam baris `PASS:` dan diakhiri `RESULT: PASS (6/6)` dengan exit `0`.
