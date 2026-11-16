# LAB-04 — Worker Join, CNI (Calico), dan Verifikasi DNS

Tujuan: join worker, pasang Calico lokal, uji DNS cluster. Bukti: 3 node Ready dan nslookup sukses.

## Konteks & State Awal

- **Starter (opsional):** `bash starter/setup.sh` hanya memastikan control-plane hasil LAB-03 siap; tidak membuat kluster.

- Node control-plane (`cka-pN-cp`) sudah berjalan dari **LAB-03**, namun belum memiliki plugin CNI.
- Kedua node worker (`cka-pN-w1` dan `cka-pN-w2`) belum tergabung ke dalam kluster (atau masih membawa state kluster lama sebelum LAB-03 di-reset).
- Manifest Calico **v3.33.0** tersedia secara lokal di `/opt/lab/manifests/calico.yaml` dan seluruh image Calico maupun `busybox:1.37` sudah di-cache di `containerd` (`k8s.io`) pada setiap node. Jangan mengunduh manifest atau image dari internet.

## Tugas

1. Di node control-plane (`cka-pN-cp`), buat bootstrap join command baru menggunakan `kubeadm token create --print-join-command`.
2. Di kedua node worker (`cka-pN-w1` dan `cka-pN-w2`), jalankan perintah join tersebut dengan menambahkan flag `--node-name=cka-pN-w1` (untuk worker 1) dan `--node-name=cka-pN-w2` (untuk worker 2).
   - Catatan: apabila worker masih menyimpan file `/etc/kubernetes/kubelet.conf` dari kluster sebelum LAB-03, jalankan `kubeadm reset -f` terlebih dahulu di worker tersebut sebelum melakukan `kubeadm join`.
3. Di node control-plane (`cka-pN-cp`), terapkan manifest CNI Calico dari file lokal:
   - `kubectl apply -f /opt/lab/manifests/calico.yaml`
4. Tunggu hingga:
   - Ketiga node (`cka-pN-cp`, `cka-pN-w1`, `cka-pN-w2`) berstatus `Ready` (`kubectl get nodes`).
   - DaemonSet `calico-node` memiliki 3 pod yang siap (`3/3`).
   - Seluruh pod `coredns` di namespace `kube-system` berstatus `Running`.
5. Uji resolusi DNS internal kluster untuk `kubernetes.default.svc.cluster.local` menggunakan pod sementara ber-image `busybox:1.37`:
   - `kubectl run dns-test --restart=Never --image=busybox:1.37 --image-pull-policy=IfNotPresent --command -- nslookup kubernetes.default.svc.cluster.local`
   - `kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/dns-test --timeout=90s`
   - `kubectl logs dns-test` lalu `kubectl delete pod dns-test --ignore-not-found`
   - Jangan gunakan `kubectl run --rm -i`: tanpa TTY perintah ini menggantung menunggu attach.

## Akses ke node worker

Worker tidak punya IP publik. Dari node control-plane, SSH ke worker memakai kunci lab yang sama:
`ssh -i /root/.ssh/lab-key root@<internal-ip-worker>` (IP internal: `kubectl get nodes -o wide`).