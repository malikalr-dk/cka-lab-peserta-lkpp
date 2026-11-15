# Lab CKA — per hari

Folder di sini mengikuti urutan sesi. Semua perintah dijalankan di control-plane (`ssh lab01`), bukan di laptop.

| Hari | Folder | Lab |
|---|---|---|
| Day 1 | `labs/day1` | LAB-01, LAB-02, LAB-03, LAB-04 |
| Day 2 | `labs/day2` | LAB-05, LAB-06, LAB-07, LAB-08 |
| Day 3 | `labs/day3` | LAB-09, LAB-10, LAB-11, LAB-12 |
| Day 4 | `labs/day4` | LAB-13, LAB-14, LAB-15, LAB-16 |
| Take-home | `labs/takehome` | LAB-17, LAB-18, LAB-19, LAB-20 |

LAB-15 dan LAB-16 adalah lab asesmen Day 4, bukan pemakaian ulang lab sebelumnya.

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
