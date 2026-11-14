# Peta Sesi Deck ↔ Lab Repo (CKA LKPP 2026)

Deck trainer terdiri dari 4 file PPTX (Day 1–4) dengan **16 sesi**, sedangkan repo ini punya **18 lab**.
Deck Day 1–3 nomornya cocok dengan lab repo; **Day 4 tidak** — deck memakai LAB-13..16 untuk topik
troubleshooting/Helm/monitoring/assessment, sementara repo memakai nomor itu untuk lab penutup celah
kurikulum. Tabel di bawah adalah pegangan saat present: sesi N memakai lab yang tertulis di kolom
**Lab repo**, bukan nomor yang disebut deck.

## Cara pakai saat present

1. Buka file deck sesuai hari: `docs/5. …Day1_v3.pptx`, `docs/6. …Day2…pptx`, `docs/7. …Day3…pptx`,
   `docs/8. …Day4…pptx` (aslinya di `input/drive-download-20261113T082124Z-1-001/`).
   Lembar kerja per hari: `docs/day1-trainer-runsheet.pdf`, `docs/day2-runsheet.pdf`,
   `docs/day3-runsheet.pdf`, `docs/day4-runsheet.pdf` (versi saku: `docs/dayN-cue-card.pdf`).
2. Setiap sesi punya satu lab. State awal disiapkan trainer sebelum sesi:
   `bash labs/LAB-NN/starter/setup.sh` di control-plane peserta.
3. Verifier dijalankan dari mesin trainer tanpa menyentuh salinan node:
   `ssh root@<cp> 'bash -s' < labs/LAB-NN/verify/verify.sh` → `RESULT: PASS (n/n)`.
4. Selesai sesi: `bash labs/LAB-NN/reset/reset.sh` supaya sesi berikutnya mulai dari state starter.

## Tabel sesi

| Sesi | Jam | Judul di deck | Lab repo | Topik lab | Perintah verifier |
|---|---|---|---|---|---|
| 01 | 09.00–10.30 | Containerization Fundamentals | LAB-01 | `kubectl` imperatif, `--dry-run=client -o yaml`, `exec`/`logs` | `ssh root@<cp> 'bash -s' < labs/LAB-01/verify/verify.sh` |
| 02 | 10.30–12.00 | Architecture & Cluster Inspection | LAB-02 | inspeksi node, komponen control-plane, endpoint API | `ssh root@<cp> 'bash -s' < labs/LAB-02/verify/verify.sh` |
| 03 | 13.00–14.30 | Control Plane Initialization | LAB-03 | `kubeadm reset` + `kubeadm init` (pod CIDR, SAN, node name) | `ssh root@<cp> 'bash -s' < labs/LAB-03/verify/verify.sh` |
| 04 | 14.30–16.00 | Worker Join & CNI Verification | LAB-04 | join 2 worker, Calico, resolusi CoreDNS | `ssh root@<cp> 'bash -s' < labs/LAB-04/verify/verify.sh` |
| 05 | 09.00–10.30 | Maintenance, Upgrade & etcd Backup | LAB-05 | cordon/drain/uncordon, snapshot etcd, restore dengan `etcdutl` | `ssh root@<cp> 'bash -s' < labs/LAB-05/verify/verify.sh` |
| 06 | 10.30–12.00 | RBAC & Cluster Recovery | LAB-06 | ServiceAccount, Role, RoleBinding, `kubectl auth can-i` | `ssh root@<cp> 'bash -s' < labs/LAB-06/verify/verify.sh` |
| 07 | 13.00–14.30 | Deploy, Scale, Update, Rollback | LAB-07 | rolling update, rollback, self-healing ReplicaSet | `ssh root@<cp> 'bash -s' < labs/LAB-07/verify/verify.sh` |
| 08 | 14.30–16.00 | Scheduling & Configuration | LAB-08 | ConfigMap/Secret, `nodeSelector`, taint + toleration | `ssh root@<cp> 'bash -s' < labs/LAB-08/verify/verify.sh` |
| 09 | 09.00–10.30 | Services, Endpoints & DNS | LAB-09 | ClusterIP/NodePort, EndpointSlice, headless + DNS | `ssh root@<cp> 'bash -s' < labs/LAB-09/verify/verify.sh` |
| 10 | 10.30–12.00 | Ingress & Network Incident | LAB-10 | IngressClass Traefik + insiden backend kosong | `ssh root@<cp> 'bash -s' < labs/LAB-10/verify/verify.sh` |
| 11 | 13.00–14.30 | PV, PVC & Data Persistence | LAB-11 | StorageClass dinamis, PVC bind, reclaim policy | `ssh root@<cp> 'bash -s' < labs/LAB-11/verify/verify.sh` |
| 12 | 14.30–16.00 | Storage Incident & Recovery | LAB-12 | aplikasi end-to-end: Deployment, Service, Ingress, PVC, ConfigMap | `ssh root@<cp> 'bash -s' < labs/LAB-12/verify/verify.sh` |
| 13 | 09.00–10.30 | Kubernetes Troubleshooting | **LAB-18** | dua fault sekaligus: kubelet worker (`cgroupDriver` + service) dan flag `kube-apiserver` | `ssh root@<cp> 'bash -s' < labs/LAB-18/verify/verify.sh` |
| 14 | 10.30–12.00 | Helm + Prometheus + Grafana | **LAB-17** | Kustomize overlay dev/prod, `helm install/upgrade/rollback` — Prometheus/Grafana **demo trainer** memakai slide deck, tanpa lab | `ssh root@<cp> 'bash -s' < labs/LAB-17/verify/verify.sh` |
| 15 | 13.00–14.30 | Integrated Incident Investigation | **LAB-12 (state bersih) + insiden Ingress LAB-10** | satu skenario berlapis: aplikasi + ingress rusak, peserta memulihkan keduanya | `labs/LAB-10/verify/verify.sh` lalu `labs/LAB-12/verify/verify.sh` (jalur `bash -s` yang sama) |
| 16 | 14.30–16.00 | Final Recovery & Assessment | **LAB-12 dari state kosong, tanpa solution key** | assessment: peserta mengerjakan sendiri, dinilai `verify.sh`, batas 75 menit | `ssh root@<cp> 'bash -s' < labs/LAB-12/verify/verify.sh` |

## Catatan nomor yang bentrok (Day 4)

| Nomor | Topik di deck | Topik di repo |
|---|---|---|
| LAB-13 | Kubernetes Troubleshooting | NetworkPolicy (Calico) |
| LAB-14 | Helm + Prometheus + Grafana | HPA + metrics-server |
| LAB-15 | Integrated Incident Investigation | Gateway API (Traefik) |
| LAB-16 | Final Recovery & Assessment | CRD + operator |
| LAB-17 | — (tidak ada di deck) | Kustomize + Helm |
| LAB-18 | — (tidak ada di deck) | Troubleshooting (2 fault) |

Saat sesi 13–16, sebut lab dengan **topiknya**, bukan nomornya, supaya peserta tidak membuka folder
yang salah.

## Lab take-home (di luar jam kelas)

Empat lab penutup celah kurikulum tidak masuk 16 sesi deck (4 sesi × 90 menit sudah penuh), jadi
diberikan sebagai latihan mandiri. File tetap bernomor `LAB-13..16`; label `EXT-n` hanya dipakai di
dokumen ini.

| Label | Folder | Topik | Perintah verifier |
|---|---|---|---|
| EXT-1 | `labs/LAB-13` | NetworkPolicy: default-deny + allow-list di Calico | `ssh root@<cp> 'bash -s' < labs/LAB-13/verify/verify.sh` |
| EXT-2 | `labs/LAB-14` | HPA + metrics-server: scale-out dan scale-in | `ssh root@<cp> 'bash -s' < labs/LAB-14/verify/verify.sh` |
| EXT-3 | `labs/LAB-15` | Gateway API: `GatewayClass`, `Gateway`, `HTTPRoute` | `ssh root@<cp> 'bash -s' < labs/LAB-15/verify/verify.sh` |
| EXT-4 | `labs/LAB-16` | CRD + operator: validasi skema dan rekonsiliasi | `ssh root@<cp> 'bash -s' < labs/LAB-16/verify/verify.sh` |

Catatan urutan: LAB-15 dan LAB-16 berbagi satu rilis Helm `traefik` dengan NodePort berbeda
(`30081` vs `30082`) — jalankan starter LAB-15 lagi sebelum verifier LAB-15 kalau LAB-16 sudah
dikerjakan lebih dulu.

## Sesi yang memakai lab yang sama

- **LAB-12** dipakai di sesi 12, 15, dan 16. `bash labs/LAB-12/reset/reset.sh` wajib dijalankan di
  antara pemakaian; untuk sesi 16 (assessment) reset harus selesai sebelum jam mulai.
- **LAB-10** dipakai di sesi 10 dan 15. Starter LAB-10 sudah membawa kondisi ingress rusak, jadi
  `bash labs/LAB-10/reset/reset.sh` wajib dijalankan sebelum sesi 15 dimulai.
- **LAB-18** verifier-nya *all-or-nothing*: 7 assertion dan kedua fault harus beres. Sesi 13 harus
  mengajarkan Fault A (worker) dan Fault B (static pod apiserver) bersama, bukan dipisah dua sesi.
