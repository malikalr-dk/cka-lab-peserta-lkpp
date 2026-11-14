# Lab CKA — Pusdatin LKPP 2026

Materi latihan hari 1–4 (18 lab) untuk kelas Certified Kubernetes Administrator.
Repo ini berisi teks tugas, state awal, skrip verifikasi, dan skrip reset. Lab **dijalankan di
cluster masing-masing peserta**, bukan di laptop — cluster sudah disiapkan trainer.

## Masuk ke cluster

Setiap peserta memegang satu cluster 3 node dan satu berkas `lab-hosts.sh` dari trainer.

```bash
bash lab-hosts.sh     # sekali saja, butuh sudo: menambah "<ip> lab0N" ke /etc/hosts
ssh lab01             # p1 -> lab01, p2 -> lab02, p3 -> lab03, p4 -> lab04
```

Login `root` tanpa kunci dan tanpa password. Hanya bisa dari jaringan venue (port 22 dibatasi
firewall). Kalau koneksi ditolak, kirim IP publik laptopmu ke trainer.

## Materi lab ada di node

```bash
ls /opt/lab/labs                 # LAB-01 .. LAB-18
cd /opt/lab/labs/LAB-02
cat task.md                      # tugas yang dikerjakan
```

Isi tiap folder lab di repo ini sama dengan yang ada di node:

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

- **LAB-18** (troubleshooting) tidak punya `starter/` maupun `reset/`: dua insidennya disuntikkan
  trainer, dan skrip penyuntiknya sengaja tidak dibagikan supaya tidak membocorkan akar masalah.
- **LAB-03** destruktif: `kubeadm reset -f` adalah bagian tugasnya. Kalau cluster tidak bisa
  dipulihkan sendiri, minta trainer membangun ulang.

## Aturan

- `kubeadm reset` **hanya** di LAB-03. Di lab lain itu menghapus clustermu sendiri.
- Jangan mengubah atau menghapus objek di namespace `kube-system` selain yang diminta lab.
- `verify.sh` yang lulus adalah bukti. Screenshot terminal bukan bukti.
- Cluster rusak dan tidak bisa dipulihkan: hubungi trainer. Trainer yang membangun ulang,
  bukan peserta.

## Peta sesi

`docs/session-lab-map.md` memetakan 16 sesi deck ke 18 lab, termasuk empat lab tambahan
(LAB-13..LAB-16) yang dikerjakan di luar jam kelas. `docs/cka-curriculum-map.md` memetakan
setiap lab ke domain silabus CKA.

## kubectl dari laptop (opsional)

Kalau trainer memberikan `cka-pN.kubeconfig`:

```bash
kubectl --kubeconfig cka-pN.kubeconfig get nodes
```

Alamat API server (`https://<ip>:6443`) tetap sama sepanjang kelas.
