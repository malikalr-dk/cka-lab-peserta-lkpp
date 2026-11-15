# Lab CKA — Pusdatin LKPP 2026

Materi latihan hari 1–4 (18 lab) untuk kelas Certified Kubernetes Administrator.
Repo ini berisi teks tugas, state awal, skrip verifikasi, dan skrip reset. Lab **dijalankan di
cluster masing-masing peserta**, bukan di laptop — cluster sudah disiapkan trainer.

## Masuk ke cluster

Setiap peserta memegang satu cluster 3 node dan satu berkas `lab-hosts.sh` dari trainer.

```bash
bash lab-hosts.sh     # Linux/macOS, sekali, butuh sudo: menambah "<ip> lab0N" ke /etc/hosts
powershell -ExecutionPolicy Bypass -File .\lab-hosts.ps1   # Windows, PowerShell as Admin
ssh lab01             # p1 -> lab01, p2 -> lab02, p3 -> lab03, p4 -> lab04
```

Login `root` tanpa kunci dan tanpa password. Hanya bisa dari jaringan venue (port 22 dibatasi
firewall). Kalau koneksi ditolak, kirim IP publik laptopmu ke trainer.

## Materi lab ada di node

```bash
ls /opt/lab/labs                 # LAB-01 .. LAB-20
cd /opt/lab/labs/LAB-02
cat task.md                      # tugas yang dikerjakan
```

Folder lab di repo ini dibagi per hari, mengikuti urutan sesi:

| Hari | Folder | Lab |
|---|---|---|
| Day 1 | `labs/day1` | LAB-01..04 |
| Day 2 | `labs/day2` | LAB-05..08 |
| Day 3 | `labs/day3` | LAB-09..12 |
| Day 4 | `labs/day4` | LAB-13, LAB-14 (+ symlink LAB-10 dan LAB-12) |
| Take-home | `labs/takehome` | LAB-17..18 |

Di node semua lab tetap di `/opt/lab/labs/LAB-NN` (tanpa folder hari). Isi tiap folder lab sama
dengan yang ada di node:

| Folder | Isi |
|---|---|
| `task.md` | tugas + apa yang diverifikasi |
| `expected_result.md` | bentuk hasil akhir yang diharapkan |
| `starter/` | state awal sesi (`setup.sh`) |
| `verify/verify.sh` | penilai otomatis: `RESULT: PASS (n/n)` = selesai |
| `reset/reset.sh` | mengembalikan lab ke state awal |

## Menilai pekerjaan sendiri

```bash
bash /opt/lab/labs/LAB-02/verify/verify.sh     # exit 0 + "RESULT: PASS (n/n)"
bash /opt/lab/labs/LAB-02/reset/reset.sh       # ulangi dari awal
```

Jalankan `verify.sh` dari node, bukan dari laptop. Skrip ini membaca cluster lewat `kubectl`.

Dua pengecualian:

- **LAB-13** (troubleshooting) tidak membawa `fault/`: dua insidennya disuntikkan trainer, dan skrip
  penyuntiknya sengaja tidak dibagikan supaya tidak membocorkan akar masalah.
- **LAB-03** destruktif: `kubeadm reset -f` adalah bagian tugasnya. Kalau cluster tidak bisa
  dipulihkan sendiri, minta trainer membangun ulang.

## Aturan

- `kubeadm reset` **hanya** di LAB-03. Di lab lain itu menghapus clustermu sendiri.
- Jangan mengubah atau menghapus objek di namespace `kube-system` selain yang diminta lab.
- `verify.sh` yang lulus adalah bukti. Screenshot terminal bukan bukti.
- Cluster rusak dan tidak bisa dipulihkan: hubungi trainer. Trainer yang membangun ulang,
  bukan peserta.

## Workbook dan lembar koreksi

Berkas cetak ada di `docs/workbook/`:

| Berkas | Isi |
|---|---|
| `workbook-cka-lkpp-fillable.pdf` | Workbook peserta (Dokumen 10) — latihan per sesi |
| `erratum-peserta.pdf` | Lembar koreksi 1 halaman untuk Day 1–4 |

Bagian lab yang berbeda dari workbook ada di lembar koreksi, bukan di workbook. Baca sekali
sebelum sesi pertama, lalu cek lagi di hari yang lab-nya disebut.

## Peta sesi

`docs/peta-lab.md` memuat jadwal 16 sesi, lab yang dipakai tiap sesi, empat lab mandiri
(LAB-17..18), dan cara menilai pekerjaan sendiri dengan `verify.sh`.

## kubectl dari laptop (opsional)

Kalau trainer memberikan `cka-pN.kubeconfig`:

```bash
kubectl --kubeconfig cka-pN.kubeconfig get nodes
```

Alamat API server (`https://<ip>:6443`) tetap sama sepanjang kelas.
