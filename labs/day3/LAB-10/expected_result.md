# Expected Result — LAB-10

State akhir yang dinilai `verify/verify.sh` di node `cka-pN-cp`:

1. **Ingress Controller Traefik:**
   - Pod Traefik di namespace `traefik` `Running`; Service Traefik mengekspos HTTP di `nodePort: 30081`.

2. **Workload & Service `app` di `gisp-app`:**
   - `Deployment` `app` punya `2/2` replika `Ready`; `Service` `app` aktif port `80` di `gisp-app`.

3. **Ingress `app-ingress`:**
   - `Ingress` `app-ingress` ada di `gisp-app` dengan host `app.lab.local`, path `/`, backend ke `Service` `app` port `80` yang ada di `gisp-app`.
   - `curl -s -H 'Host: app.lab.local' http://localhost:30081/` mengembalikan `HTTP 200` dan halaman nginx (`Welcome to nginx!`).

4. **Ingress `broken-ingress` (sudah diperbaiki):**
   - `Ingress` `broken-ingress` ada di `gisp-app` dengan host `broken.lab.local` dan backend ke `Service` serta port valid di `gisp-app`.
   - `curl -s -H 'Host: broken.lab.local' http://localhost:30081/` mengembalikan `HTTP 200` dan halaman nginx (`Welcome to nginx!`).

5. **Output Verifier:**
   - `verify/verify.sh` mencetak 7 baris `PASS:` lalu `RESULT: PASS (7/7)` dan exit code `0`.