# Expected Result — LAB-06

`verify/verify.sh` menilai state akhir di node `cka-pN-cp`:

1. **ServiceAccount `dev-sa`:**
   - `ServiceAccount` `dev-sa` tersedia di namespace `cka-lab06`.

2. **Evaluasi izin (`kubectl auth can-i --as=system:serviceaccount:cka-lab06:dev-sa`):**
   - `list pods -n cka-lab06` mengembalikan `yes`.
   - `delete pods -n cka-lab06` mengembalikan `no`.
   - `list pods -n default` mengembalikan `no`.
   - `list nodes` mengembalikan `yes`.
   - `get secrets -n cka-lab06` mengembalikan `no`.

3. **Aturan Role tanpa wildcard (`*`):**
   - Minimal satu `Role` ada di namespace `cka-lab06`, dan tidak ada `Role` di `cka-lab06` yang menggunakan `*` pada `rules[].verbs` maupun `rules[].resources`.

4. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 7 baris `PASS:` dan diakhiri dengan `RESULT: PASS (7/7)` serta kode keluar `0`.