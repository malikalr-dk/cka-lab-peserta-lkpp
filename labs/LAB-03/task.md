# LAB-03 — Inisialisasi Control Plane dengan `kubeadm init` (Destruktif)

Tujuan: membongkar kluster yang sedang berjalan dengan `kubeadm reset -f`, kemudian menginisialisasi ulang control plane menggunakan `kubeadm init` dengan parameter jaringan dan sertifikat yang tepat serta menyiapkan `/root/.kube/config`.

> **PERINGATAN (DESTRUKTIF):**
> Lab ini **menghancurkan kluster yang sedang berjalan** secara sengaja. Menjalankan `kubeadm reset -f` akan menghapus seluruh objek kluster, sertifikat PKI (`/etc/kubernetes/pki`), data `etcd` (`/var/lib/etcd`), dan memutus koneksi node worker (`cka-pN-w1`, `cka-pN-w2`) serta `kubeconfig` di laptop Anda.
>
> **Cara Pemulihan (Recovery):**
> - Sebelum memulai `kubeadm reset -f`, catat IP private node control-plane (`ip -4 addr`), IP publik/floating control-plane (dapat dilihat dari URL `server:` pada `/root/.kube/config` sebelum reset), dan nama node (`hostname`).
> - Apabila inisialisasi gagal di tengah jalan, jalankan kembali `kubeadm reset -f`, bersihkan `/etc/cni/net.d` serta `/var/lib/etcd`, lalu ulangi `kubeadm init`.
> - Apabila mesin masih bermasalah dan Anda membutuhkan pemulihan kluster penuh dari sisi trainer, minta trainer menjalankan `./lab-cluster.sh init pN` (mis. `p1`) dari workstation trainer.

## Konteks & State Awal

- Anda login melalui SSH sebagai `root` di node control-plane `cka-pN-cp`.
- Paket `kubeadm`, `kubelet`, `kubectl` (**v1.37.2**) dan `containerd` sudah terpasang, dan seluruh image sistem control-plane sudah ter-cache secara lokal di namespace `k8s.io`.
- Kluster awal masih berjalan dan akan Anda bongkar pada langkah pertama.

## Tugas

1. Sebelum membongkar kluster, periksa dan catat:
   - Nama node control-plane (`cka-pN-cp`, gunakan `hostname`).
   - IP private control-plane (`<cp private ip>`, gunakan `hostname -I` atau `ip -4 addr`).
   - IP publik / floating control-plane (`<cp floating ip>`, dapat dilihat di `/root/.kube/config` atau dari informasi sesi Anda).
2. Bongkar instalasi control-plane yang ada dengan menjalankan:
   - `kubeadm reset -f`
   - Bersihkan sisa konfigurasi CNI (`find /etc/cni/net.d -mindepth 1 -delete`) dan data `/var/lib/etcd` bila masih tersisa. **Jangan menghapus direktori `/etc/cni/net.d` itu sendiri** — containerd 2.x akan mati dan `kubeadm init` gagal dengan `connection refused`.
   - Tunggu containerd siap sebelum lanjut: `for _ in $(seq 1 30); do crictl --timeout=2s ps >/dev/null 2>&1 && break; sleep 1; done`
3. Jalankan `kubeadm init` untuk membangun kembali control-plane dengan keempat parameter berikut:
   - `--pod-network-cidr=192.168.0.0/16`
   - `--apiserver-advertise-address=<cp private ip>`
   - `--apiserver-cert-extra-sans=<cp floating ip>`
   - `--node-name=cka-pN-cp` (sesuaikan `pN` dengan nomor peserta Anda, mis. `cka-p1-cp`)
4. Siapkan kubeconfig untuk `root` di `/root/.kube/config` dengan menyalin `/etc/kubernetes/admin.conf`.
5. Verifikasi bahwa:
   - `kubectl get --raw /healthz` mengembalikan `ok`.
   - Container `kube-apiserver` berjalan (`crictl ps`).
   - `kubectl get nodes` menampilkan node `cka-pN-cp` (status `NotReady` maupun `Ready` keduanya diperbolehkan pada tahap ini karena CNI Calico dan worker join akan dikerjakan di **LAB-04**).
