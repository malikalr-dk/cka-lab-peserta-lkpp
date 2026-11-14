# Expected Result — LAB-05

`verify/verify.sh` menilai state akhir di node `cka-pN-cp`:

1. **Status node worker `cka-pN-w1`:**
   - Node `cka-pN-w1` terdaftar di kluster, berstatus `Ready`, dan **schedulable** (`spec.unschedulable` tidak bernilai `true` setelah di-*uncordon*).

2. **File snapshot `etcd` (`/root/lab/etcd-snap.db`):**
   - File `/root/lab/etcd-snap.db` tersedia di `cka-pN-cp` dan ukurannya tidak kosong (`> 0` byte).

3. **Validitas snapshot (`etcdutl snapshot status`):**
   - Menjalankan `etcdutl snapshot status /root/lab/etcd-snap.db -w table` berhasil (exit `0`) dan mencetak nilai *hash* yang valid.

4. **Direktori hasil restore (`/root/lab/etcd-restore`):**
   - Direktori `/root/lab/etcd-restore/member/snap` tersedia sebagai bukti bahwa perintah `etcdutl snapshot restore` sudah dijalankan ke direktori *scratch* (tanpa menyentuh `/var/lib/etcd`).

5. **Output verifier:**
   - Menjalankan `verify/verify.sh` mencetak 4 baris `PASS:` dan diakhiri dengan `RESULT: PASS (4/4)` serta kode keluar `0`.