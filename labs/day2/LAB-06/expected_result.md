# Expected Result — LAB-06

`verify/verify.sh` menilai state akhir di node `cka-pN-cp`:

1. **ServiceAccount `dev-sa`:**
   - `ServiceAccount` `dev-sa` tersedia di namespace `gisp-app`.

2. **Evaluasi izin (`kubectl auth can-i --as=system:serviceaccount:gisp-app:dev-sa`):**
   - `list pods -n gisp-app` mengembalikan `yes`.
   - `delete pods -n gisp-app` mengembalikan `no`.
   - `list pods -n default` mengembalikan `no`.
   - `list nodes` mengembalikan `yes`.
   - `get secrets -n gisp-app` mengembalikan `no`.

3. **Aturan Role tanpa wildcard (`*`):**
   - Minimal satu `Role` ada di namespace `gisp-app`, dan tidak ada `Role` di `gisp-app` yang menggunakan `*` pada `rules[].verbs` maupun `rules[].resources`.

4. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 7 baris `PASS:` dan diakhiri dengan `RESULT: PASS (7/7)` serta kode keluar `0`.