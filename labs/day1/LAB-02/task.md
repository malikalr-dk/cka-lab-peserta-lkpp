# LAB-02 — Inspeksi Arsitektur Kluster (Read-Only)

Tujuan: inspeksi node, namespace, dan pod kube-system. Bukti: laporan di `/root/lab/lab02-report.txt`.

## Konteks & State Awal

- **Starter (opsional):** `bash starter/setup.sh` hanya membersihkan `/root/lab` dari percobaan sebelumnya; tanpa itu pun lab jalan.

- Kluster 3-node (`cka-pN-cp`, `cka-pN-w1`, `cka-pN-w2`) sehat (`Ready`).
- Lab ini **read-only** untuk objek Kubernetes: jangan hapus atau ubah node/pod sistem.
- `kubectl` boleh dari laptopmu atau SSH ke `cka-pN-cp`; laporan akhir **wajib** di `cka-pN-cp` pada `/root/lab/lab02-report.txt`.

## Tugas

1. Periksa daftar node di kluster (`kubectl get nodes -o wide`) dan identifikasi mana node control-plane (`cka-pN-cp`) serta mana node worker (`cka-pN-w1`, `cka-pN-w2`). Pastikan ketiganya berstatus `Ready`.
2. Periksa kesehatan API server serta daftar seluruh namespace di kluster.
3. Periksa seluruh pod di namespace `kube-system` dan identifikasi komponen control-plane (static pods) maupun komponen jaringan dan DNS (`etcd`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `coredns`, `calico-node`).
4. Periksa alamat endpoint API server kluster (misalnya melalui `kubectl config view --minify` atau `kubectl cluster-info`).
5. Tulis file laporan di `/root/lab/lab02-report.txt` pada node control-plane (`cka-pN-cp`) yang memuat:
   - Keempat nama komponen control-plane: `etcd`, `kube-apiserver`, `kube-controller-manager`, dan `kube-scheduler`.
   - Alamat endpoint API server aktif (mis. `https://<ip-cp>:6443`).