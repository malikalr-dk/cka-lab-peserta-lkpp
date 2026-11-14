# LAB-05 — Maintenance: Cordon/Drain Node & Backup/Restore etcd

Tujuan: melakukan pemeliharaan terencana pada node worker menggunakan `cordon`, `drain`, dan `uncordon`, serta membuat cadangan (*snapshot*) database `etcd`, memverifikasi integritasnya, dan memulihkannya ke direktori *scratch* tanpa menyentuh `etcd` yang sedang berjalan.

> **PERINGATAN KERAS — JANGAN TIMPA ETCD AKTIF:**
> Pada langkah *restore*, Anda **WAJIB** memulihkan snapshot ke direktori terpisah (`/root/lab/etcd-restore`). **JANGAN PERNAH** mengarahkan `--data-dir` ke `/var/lib/etcd` atau memodifikasi manifest static pod `etcd.yaml` pada lab ini. Instance `etcd` yang sedang berjalan di kluster **tidak boleh disentuh** agar kluster tetap hidup untuk lab berikutnya.

> **Catatan Kurikulum (Upgrade Versi Kluster):**
> Prosedur upgrade versi Kubernetes (`kubeadm upgrade plan` / `kubeadm upgrade apply`) **tidak diuji oleh verifier** pada lab ini karena node tidak memiliki repositori paket, dan akan ditampilkan sebagai **demo oleh trainer**.

## Konteks & State Awal

- Kluster 3-node (`cka-pN-cp`, `cka-pN-w1`, `cka-pN-w2`) dalam keadaan sehat (`Ready` dan *schedulable*).
- Anda login sebagai `root` di node control-plane (`cka-pN-cp`).
- Utilitas `kubectl`, `etcdctl`, dan `etcdutl` telah tersedia di `PATH` pada `cka-pN-cp`.
- Sertifikat PKI `etcd` berada di `/etc/kubernetes/pki/etcd/`.

## Tugas

1. **Pemeliharaan Node (`cordon`, `drain`, `uncordon`):**
   - Tandai node worker pertama (`cka-pN-w1`) agar tidak menerima penjadwalan pod baru (`cordon`), lalu buktikan bahwa status node menampilkan `SchedulingDisabled`.
   - Kosongkan (*drain*) node `cka-pN-w1` menggunakan opsi `--ignore-daemonsets --delete-emptydir-data --force`.
   - Pastikan tidak ada lagi pod non-DaemonSet yang berjalan di `cka-pN-w1`.
   - Kembalikan node `cka-pN-w1` ke status normal (`uncordon`) dan pastikan status `SchedulingDisabled` telah hilang sehingga pod dapat dijadwalkan kembali ke node tersebut.

2. **Backup Snapshot `etcd`:**
   - Buat direktori `/root/lab` bila belum ada.
   - Ambil snapshot dari instance `etcd` lokal (`https://127.0.0.1:2379`) menggunakan `etcdctl snapshot save` dan simpan ke `/root/lab/etcd-snap.db`.
   - Gunakan sertifikat autentikasi berikut:
     - `--cacert=/etc/kubernetes/pki/etcd/ca.crt`
     - `--cert=/etc/kubernetes/pki/etcd/server.crt`
     - `--key=/etc/kubernetes/pki/etcd/server.key`

3. **Verifikasi Snapshot `etcd`:**
   - Buktikan bahwa file `/root/lab/etcd-snap.db` valid dan utuh dengan menjalankan `etcdutl snapshot status /root/lab/etcd-snap.db -w table`.

4. **Simulasi Restore ke Direktori Scratch:**
   - Pulihkan snapshot `/root/lab/etcd-snap.db` ke direktori baru `/root/lab/etcd-restore` menggunakan `etcdutl snapshot restore ... --data-dir /root/lab/etcd-restore`.
   - Periksa isi direktori hasil restore dan pastikan struktur `/root/lab/etcd-restore/member/snap` terbentuk.
   - **Ingat:** biarkan `etcd` aktif di `/var/lib/etcd` tetap berjalan seperti semula.
