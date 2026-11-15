# Lab CKA — per hari

Folder di sini mengikuti urutan sesi. Semua perintah dijalankan di control-plane (`ssh lab01`), bukan di laptop.

| Hari | Folder | Lab |
|---|---|---|
| Day 1 | `labs/day1` | LAB-01, LAB-02, LAB-03, LAB-04 |
| Day 2 | `labs/day2` | LAB-05, LAB-06, LAB-07, LAB-08 |
| Day 3 | `labs/day3` | LAB-09, LAB-10, LAB-11, LAB-12 |
| Day 4 | `labs/day4` | LAB-13, LAB-14, plus LAB-10 dan LAB-12 (dipakai ulang) |
| Take-home | `labs/takehome` | LAB-15, LAB-16, LAB-17, LAB-18 |

`labs/day4/LAB-10` dan `labs/day4/LAB-12` adalah symlink ke `labs/day3/`. Kalau clone di Windows
membuatnya jadi file teks (bukan folder), pakai `labs/day3/LAB-10` dan `labs/day3/LAB-12` langsung.

## Path di node

Folder ini untuk dibaca. Yang dieksekusi ada di node, di `/opt/lab/labs/LAB-NN`:

    ssh lab01
    ls /opt/lab/labs
    bash /opt/lab/labs/LAB-02/verify/verify.sh     # exit 0 dan "RESULT: PASS (n/n)" = selesai
    bash /opt/lab/labs/LAB-02/reset/reset.sh       # kembali ke state awal

## Aturan

1. `kubeadm reset` hanya di LAB-03.
2. Jangan sentuh `kube-system`.
3. Cluster rusak: panggil trainer.
