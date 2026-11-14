# Expected Result — LAB-15

State akhir yang dinilai `verify/verify.sh` di node `cka-pN-cp`:

1. **CRD Gateway API & `GatewayClass`:**
   - CRD `gatewayclasses.gateway.networking.k8s.io`, `gateways.gateway.networking.k8s.io`, dan `httproutes.gateway.networking.k8s.io` tersedia dengan kondisi `Established=True`.
   - Objek `GatewayClass` `traefik` memiliki kondisi `Accepted=True`.

2. **Objek `Gateway` `web-gateway`:**
   - `Gateway` `web-gateway` di namespace `cka-lab15` menggunakan `gatewayClassName: traefik` dengan listener `HTTP` pada port `80`.
   - `Gateway` `web-gateway` memiliki kondisi `Accepted=True` serta `status.addresses` terisi (`Programmed=True`).

3. **Objek `HTTPRoute` `web-route`:**
   - `HTTPRoute` `web-route` di namespace `cka-lab15` melayani hostname `web.gw.local`, terhubung ke `web-gateway`, dan memiliki kondisi parent `Accepted=True` serta `ResolvedRefs=True`.
   - Permintaan HTTP `curl -s -H 'Host: web.gw.local' http://localhost:30081/` mengembalikan halaman sambutan nginx (`Welcome to nginx!`).

4. **Objek `HTTPRoute` `broken-route` (sudah diperbaiki):**
   - `HTTPRoute` `broken-route` di namespace `cka-lab15` memiliki `backendRefs` yang mengarah ke `Service` `web` pada port `80`, dengan kondisi parent `Accepted=True` serta `ResolvedRefs=True`.
   - Permintaan HTTP `curl -s -H 'Host: broken.gw.local' http://localhost:30081/` mengembalikan halaman sambutan nginx (`Welcome to nginx!`).

5. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 9 baris `PASS:` dan diakhiri dengan `RESULT: PASS (9/9)` serta kode keluar `0`.