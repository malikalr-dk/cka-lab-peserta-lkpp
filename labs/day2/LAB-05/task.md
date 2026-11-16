# LAB-05 — Maintenance: Cordon/Drain Node & Backup/Restore etcd

Tujuan: cordon/drain/uncordon w1; snapshot dan restore etcd ke scratch. Bukti: snap valid, etcd aktif utuh.

> **PERINGATAN KERAS — JANGAN TIMPA ETCD AKTIF:**
> Pada langkah *restore*, **wajib** pulihkan snapshot ke direktori terpisah (`/root/lab/etcd-restore`). **JANGAN PERNAH** mengarahkan `--data-dir` ke `/var/lib/etcd` atau memodifikasi manifest static pod `etcd.yaml` pada lab ini. Instance `etcd` yang sedang berjalan di kluster **tidak boleh disentuh** agar kluster tetap hidup untuk lab berikutnya.

> **Catatan Kurikulum (Upgrade Versi Kluster):**
> Prosedur upgrade versi Kubernetes (`kubeadm upgrade plan` / `kubeadm upgrade apply`) **tidak diuji oleh verifier** pada lab ini karena node tidak memiliki repositori paket, dan akan ditampilkan sebagai **demo oleh trainer**.

## Konteks & State Awal

- **Starter (opsional):** `bash starter/setup.sh` melepas `cordon` di `cka-pN-w1` dan menghapus snapshot/PVC lama. Wajib kalau sesi sebelumnya sempat `drain`.

- Kluster 3-node (`cka-pN-cp`, `cka-pN-w1`, `cka-pN-w2`) sehat (`Ready` dan *schedulable*).
- Login sebagai `root` di node control-plane (`cka-pN-cp`).
- Utilitas `kubectl`, `etcdctl`, dan `etcdutl` sudah ada di `PATH` pada `cka-pN-cp`.
- Sertifikat PKI `etcd` berada di `/etc/kubernetes/pki/etcd/`.

## Tugas

1. **Pemeliharaan node: cordon, drain, uncordon:**
   - Tandai node worker pertama (`cka-pN-w1`) agar tidak menerima penjadwalan pod baru (`cordon`), lalu buktikan bahwa status node menampilkan `SchedulingDisabled`.
   - Kosongkan (*drain*) node `cka-pN-w1` menggunakan opsi `--ignore-daemonsets --delete-emptydir-data --force`.
   - Pastikan tidak ada lagi pod non-DaemonSet yang berjalan di `cka-pN-w1`.
   - Kembalikan node `cka-pN-w1` ke status normal (`uncordon`) dan pastikan status `SchedulingDisabled` sudah hilang sehingga pod dapat dijadwalkan kembali ke node tersebut.

2. **Backup snapshot `etcd`:**
   - Buat direktori `/root/lab` bila belum ada.
   - Ambil snapshot dari instance `etcd` lokal (`https://127.0.0.1:2379`) menggunakan `etcdctl snapshot save` dan simpan ke `/root/lab/etcd-snap.db`.
   - Gunakan sertifikat autentikasi berikut:
     - `--cacert=/etc/kubernetes/pki/etcd/ca.crt`
     - `--cert=/etc/kubernetes/pki/etcd/server.crt`
     - `--key=/etc/kubernetes/pki/etcd/server.key`

3. **Verifikasi snapshot `etcd`:**
   - Buktikan bahwa file `/root/lab/etcd-snap.db` valid dan utuh dengan menjalankan `etcdutl snapshot status /root/lab/etcd-snap.db -w table`.

4. **Simulasi restore ke direktori scratch:**
   - Pulihkan snapshot `/root/lab/etcd-snap.db` ke direktori baru `/root/lab/etcd-restore` menggunakan `etcdutl snapshot restore ... --data-dir /root/lab/etcd-restore`.
   - Periksa isi direktori hasil restore dan pastikan struktur `/root/lab/etcd-restore/member/snap` terbentuk.
   - **Ingat:** biarkan `etcd` aktif di `/var/lib/etcd` tetap berjalan seperti semula.