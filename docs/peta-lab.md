# Peta Sesi dan Lab

Kelas ini 4 hari, 16 sesi, 18 lab. Satu sesi satu lab. Nomor lab sama dengan nomor sesi, kecuali
sesi 15 dan 16 yang memakai ulang lab sebelumnya.

## Jam

| Sesi | Jam |
|---|---|
| 1 | 09.00–10.30 |
| 2 | 10.30–12.00 |
| 3 | 13.00–14.30 |
| 4 | 14.30–16.00 |

Istirahat 12.00–13.00.

## Day 1

| Sesi | Topik | Lab |
|---|---|---|
| 1 | Containerization Fundamentals | LAB-01 |
| 2 | Architecture & Cluster Inspection | LAB-02 |
| 3 | Control Plane Initialization | LAB-03 |
| 4 | Worker Join & CNI Verification | LAB-04 |

## Day 2

| Sesi | Topik | Lab |
|---|---|---|
| 5 | Maintenance, Upgrade & etcd Backup | LAB-05 |
| 6 | RBAC & Cluster Recovery | LAB-06 |
| 7 | Deploy, Scale, Update, Rollback | LAB-07 |
| 8 | Scheduling & Configuration | LAB-08 |

## Day 3

| Sesi | Topik | Lab |
|---|---|---|
| 9 | Services, Endpoints & DNS | LAB-09 |
| 10 | Ingress & Network Incident | LAB-10 |
| 11 | PV, PVC & Data Persistence | LAB-11 |
| 12 | Storage Incident & Recovery | LAB-12 |

## Day 4

| Sesi | Topik | Lab |
|---|---|---|
| 13 | Kubernetes Troubleshooting | LAB-13 |
| 14 | Helm, Kustomize, Prometheus & Grafana | LAB-14 |
| 15 | Integrated Incident Investigation | LAB-15 |
| 16 | Final Recovery & Assessment | LAB-16 |

Sesi 15 dan 16 adalah asesmen individual. Keduanya memakai lab sendiri (LAB-15 dan LAB-16), dan
state awalnya disiapkan ulang sebelum sesi dimulai.

## Lab mandiri

Empat lab terakhir tidak masuk jam kelas. Kerjakan di luar sesi, sendiri atau berkelompok.

| Lab | Topik |
|---|---|
| LAB-17 | NetworkPolicy: default-deny dan allow-list |
| LAB-18 | HPA dengan metrics-server: scale-out dan scale-in |
| LAB-19 | Gateway API: GatewayClass, Gateway, HTTPRoute |
| LAB-20 | CRD dan operator: validasi skema, rekonsiliasi |

LAB-19 dan LAB-20 memakai satu rilis Traefik dengan NodePort berbeda. Kerjakan berurutan, dan minta
trainer menyiapkan ulang state lab yang lebih dulu kalau kamu mau mengulang.

## Cara mengerjakan satu lab

1. Baca tugasnya.

   ```bash
   ls /opt/lab/labs
   cd /opt/lab/labs/LAB-02
   cat task.md
   ```

2. Kerjakan di cluster, bukan di laptop. Tulis berkas hasil di path yang disebut `task.md`.
3. Nilai pekerjaanmu sendiri.

   ```bash
   bash /opt/lab/labs/LAB-02/verify/verify.sh
   ```

   Selesai kalau keluar `RESULT: PASS (n/n)` dengan exit 0. Kalau FAIL, baca assertion yang gagal:
   pesan itu menyebut objek dan nilai yang diharapkan.

4. Mau mengulang dari awal:

   ```bash
   bash /opt/lab/labs/LAB-02/reset/reset.sh
   ```

Verifier yang lulus adalah bukti. Screenshot terminal bukan bukti.

## Yang perlu diingat

- LAB-03 destruktif. `kubeadm reset` memang bagian tugasnya, dan cluster lamamu hilang.
- Di lab lain, `kubeadm reset` menghapus clustermu sendiri tanpa alasan.
- Jangan mengubah objek di `kube-system` selain yang diminta lab.
- Cluster rusak dan tidak bisa dipulihkan: hubungi trainer. Trainer yang membangun ulang.
