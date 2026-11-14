# Expected Result — LAB-10

State akhir yang dinilai oleh `verify/verify.sh` di node `cka-pN-cp`:

1. **Ingress Controller Traefik:**
   - Pod Traefik di namespace `traefik` berstatus `Running`, dan Service Traefik mengekspos port HTTP pada `nodePort: 30081`.

2. **Workload & Service `app` di `cka-lab10`:**
   - Deployment `app` memiliki `2/2` replika `Ready` dan Service `app` aktif pada port `80` di namespace `cka-lab10`.

3. **Ingress `app-ingress`:**
   - Objek `Ingress` `app-ingress` tersedia di namespace `cka-lab10` dengan host `app.lab.local`, path `/`, dan backend yang mengarah ke Service `app` port `80` yang benar-benar ada di `cka-lab10`.
   - `curl -s -H 'Host: app.lab.local' http://localhost:30081/` mengembalikan `HTTP 200` beserta halaman sambutan nginx (`Welcome to nginx!`).

4. **Ingress `broken-ingress` (Telah Diperbaiki):**
   - Objek `Ingress` `broken-ingress` tersedia di namespace `cka-lab10` dengan host `broken.lab.local` dan backend yang mengarah ke Service serta port yang valid di `cka-lab10`.
   - `curl -s -H 'Host: broken.lab.local' http://localhost:30081/` mengembalikan `HTTP 200` beserta halaman sambutan nginx (`Welcome to nginx!`).

5. **Output Verifier:**
   - Menjalankan `verify/verify.sh` mencetak 7 baris `PASS:` dan diakhiri dengan `RESULT: PASS (7/7)` serta kode keluar `0`.
