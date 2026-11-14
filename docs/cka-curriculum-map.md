# CKA Curriculum → Lab Map (LKPP 2026)

Sumber kurikulum: `cncf/curriculum` → `CKA_Curriculum_v1.37.pdf`. Dokumen itu memuat 5 domain, 36 butir.
Dokumen ini memetakan tiap butir ke lab yang ada, menandai yang kurang, dan mengusulkan lab tambahan.
Tujuannya bukan gap analysis saja: hasil akhirnya adalah daftar lab versi kita sendiri, yang siap dibangun.

## 1. Version matrix — semua versi terbaru, diverifikasi 2026-11-14

| Komponen | Versi | Sumber |
|---|---|---|
| Kubernetes (kubeadm/kubelet/kubectl) | **v1.37.2** | `dl.k8s.io/release/stable.txt` |
| Calico (CNI + NetworkPolicy) | **v3.33.0** | projectcalico/calico latest release, 2026-10-01 |
| Helm | **v4.3.2** | helm/helm latest release, 2026-11-13 |
| Traefik (Ingress) | chart **42.4.0** | traefik/traefik-helm-chart, 2026-11-12 |
| local-path-provisioner (storage) | **v0.0.37** | rancher/local-path-provisioner, 2026-08-05 |
| metrics-server | **v0.9.1** | kubernetes-sigs/metrics-server, 2026-10-29 |
| Gateway API (CRD) | **v1.7.0** | kubernetes-sigs/gateway-api, 2026-10-29 |
| kube-prometheus-stack | **93.3.0** | prometheus-community/helm-charts, 2026-11-13 |

Catatan: set di Windows (`C:\cka-lab\artifacts\VERSIONS.md`) sudah 1.37.2 / 3.33.0 / 42.4.0 / 0.0.37 / 4.3.2 —
cocok. Yang cloud masih 1.32.13 / Calico 3.28.2 dan **harus di-rebuild** ke angka di atas.

## 2. Coverage — 36 butir

Kolom Lab: nomor lab yang sekarang menutup butir itu. `—` = belum ada.

### Storage (10%)
| Butir | Lab | Status |
|---|---|---|
| Implement storage classes & dynamic provisioning | LAB-11 | covered |
| Configure volume types, access modes, reclaim policies | LAB-11 | **partial** — reclaim policy belum dilatih |
| Manage PV & PVC | LAB-11 | covered |

### Workloads & Scheduling (15%)
| Butir | Lab | Status |
|---|---|---|
| Deployments, rolling update, rollback | LAB-07 | covered |
| ConfigMaps & Secrets | LAB-08 | covered |
| Configure workload autoscaling | LAB-14 | covered |
| Self-healing primitives | LAB-07 | covered |
| Pod admission & scheduling (limits, node affinity) | LAB-08 | **partial** — affinity/taint/toleration belum ada |

### Servicing & Networking (20%)
| Butir | Lab | Status |
|---|---|---|
| Pod connectivity | LAB-09 | covered |
| Define and enforce Network Policies | LAB-13 | covered |
| ClusterIP / NodePort / LoadBalancer + endpoints | LAB-09 | covered (LB konseptual) |
| Use the Gateway API to manage Ingress traffic | LAB-15 | covered |
| Ingress controllers & Ingress resources | LAB-10 | covered |
| CoreDNS | LAB-09, LAB-10 | covered |

### Troubleshooting (30%)
| Butir | Lab | Status |
|---|---|---|
| Troubleshoot clusters and nodes | LAB-13 | **partial** — node fault masih opsional |
| Troubleshoot cluster components | LAB-13 | partial |
| Monitor cluster & application resource usage | LAB-14 | covered |
| Manage and evaluate container output streams | LAB-01 | covered — `kubectl logs` + `kubectl exec` dilatih di LAB-01 |
| Troubleshoot services and networking | LAB-10 | covered |

### Cluster Architecture, Installation & Configuration (25%)
| Butir | Lab | Status |
|---|---|---|
| Manage RBAC | LAB-06 | covered |
| Prepare underlying infrastructure for installing a cluster | LAB-03 | **partial** — VM sudah disiapkan trainer |
| Create & manage clusters using kubeadm | LAB-03, LAB-04 | covered |
| Manage the lifecycle of Kubernetes clusters | LAB-05 | partial — upgrade time-boxed di staging |
| Implement and configure a highly-available control plane | — | **MISSING** |
| Use Helm and Kustomize | LAB-17 | covered |
| Understand extension interfaces (CNI, CSI, CRI) | LAB-04 | **partial** — implicit, tidak diajarkan eksplisit |
| Understand CRDs, install & configure operators | LAB-16 | covered |

Ringkas: **33 covered, 5 partial, 1 missing** (HA control plane — usulan demo, bukan lab).

## 3. Usulan lab versi kita

### Lab baru (4)
| Kode | Judul | Domain | Durasi | Catatan build |
|---|---|---|---|---|
| LAB-N1 | NetworkPolicy: default-deny, allow-list, uji dengan 2 Pod + `curl` | Networking | 60' | Butuh Calico enforce (sudah ada). Verifier: koneksi harus gagal/lulus sesuai policy |
| LAB-N2 | HPA + metrics-server: beban sintetis, scale-out, scale-in | Workloads | 45' | Butuh metrics-server v0.9.1 dan pod yang bisa dibebani (`busybox` loop) |
| LAB-N3 | Gateway API: GatewayClass + Gateway + HTTPRoute ke aplikasi | Networking | 60' | Butuh CRD v1.7.0; Traefik 42.4.0 sudah mendukung Gateway API |
| LAB-N4 | CRD + operator: pasang CRD, install operator, buat custom resource, lihat rekonsiliasi | Cluster Arch | 60' | Operator paling ringan: `podinfo`/`sample-controller`; dari chart lokal saat kelas |

### Sisipan ke lab yang ada (3)
| Kode | Sisipan | Lab | Tambahan waktu |
|---|---|---|---|
| LAB-S1 | nodeAffinity, taints/tolerations, nodeSelector | LAB-08 | +20' |
| LAB-S2 | Kustomize: base + overlay, bandingkan dengan Helm | LAB-14 | +20' |
| LAB-S3 | CNI/CSI/CRI: lihat config containerd, StorageClass sebagai CSI, plugin CNI terpasang | LAB-04 | +15' |

### HA control plane — usulan: demo, bukan lab
Butir "highly-available control plane" realistisnya 3 CP + stacked etcd = 6 node per kluster. Itu 6 GB per peserta
dan 24 GB total — di luar kapasitas. Usulan: demo trainer di kluster sendiri (3 CP), peserta mengamati,
dan butir dicatat sebagai "demonstrated, not practiced". Keputusan ini perlu persetujuan karena menyimpang
dari kurikulum penuh.

## 4. Konsekuensi jadwal — tetap 16 sesi

Menambah 4 lab butuh 4 slot. Usulan penggabungan, supaya tetap 4 hari × 4 sesi:

| Dari | Jadi | Alasan |
|---|---|---|
| LAB-01 (containerization) + LAB-02 (architecture) | 1 sesi gabungan | Storage 10%, architecture inspection murni baca — dua-duanya bisa dipadatkan |
| LAB-11 + LAB-12 (storage) | 1 sesi gabungan | Storage cuma 10% dari exam, sekarang dapat 2 sesi (13%) |
| LAB-05 (maintenance+etcd) tetap, LAB-06 (RBAC+recovery) tetap | — | Troubleshooting 30% dan RBAC 25% tidak boleh dipotong |

Hasil: 16 sesi tetap, komposisi lebih dekat ke bobot exam (Troubleshooting 30% dapat 4 sesi, Networking 20% dapat 4 sesi).

## 5. Yang perlu lu putuskan

- [ ] 4 lab baru (N1 NetPol, N2 HPA, N3 Gateway API, N4 CRD/operator) — semua, atau subset?
- [ ] 3 sisipan (S1 affinity, S2 Kustomize, S3 CNI/CSI/CRI) — setuju?
- [ ] Penggabungan LAB-01+02 dan LAB-11+12 — setuju, atau lu mau tambah hari?
- [ ] HA control plane: demo saja (usulan gua), atau tetap dibuat lab dan kluster peserta diturunkan jadi 2 node?
- [ ] Version bump ke 1.37.2 / Calico 3.33.0 — konfirmasi, karena golden image harus di-rebuild
- [ ] GISP image: bikin aplikasi tiruan (Go/Python ~100 baris, endpoint versi) atau pakai image publik?
