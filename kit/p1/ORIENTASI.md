# Lab CKA — peserta p1

## Masuk ke cluster
    ssh lab01         # setelah alias /etc/hosts dijalankan sekali
    ssh root@157.10.160.102      # kalau alias belum dipasang

Tanpa password, tanpa kunci. Hanya bisa dari jaringan venue (firewall allowlist). Kalau ditolak,
kirim IP publik laptopmu ke trainer untuk didaftarkan.

## Pasang alias nama (sekali saja)
Linux/macOS:
    bash lab-hosts.sh  # menambah "<fip> lab01" ke /etc/hosts, butuh sudo, aman diulang

Windows (PowerShell as Administrator, sekali saja):
    powershell -ExecutionPolicy Bypass -File .\lab-hosts.ps1

Windows tanpa alias juga boleh: langsung  dan .
Semua perintah lab tetap dijalankan di node, jadi Windows tidak perlu bash/WSL.

## Materi lab ada di node
    ls /opt/lab/labs
    cd /opt/lab/labs/LAB-02

## Cara menilai pekerjaanmu sendiri
    bash /opt/lab/labs/LAB-02/verify/verify.sh     # exit 0 dan "RESULT: PASS (n/n)" = selesai

## Cara mengembalikan state lab
    bash /opt/lab/labs/LAB-02/reset/reset.sh

## Aturan
- `kubeadm reset` hanya di LAB-03. Di lab lain itu menghapus clustermu sendiri.
- Folder kit ini milikmu. Halaman rekap kelas (kit/index.html) dipegang trainer — jangan diminta,
  jangan dibagikan.
- Jangan mengubah atau menghapus apa pun di namespace `kube-system`.
- Cluster rusak dan tidak bisa dipulihkan: hubungi trainer. Trainer yang menjalankan
  `./lab-cluster.sh init p1`, bukan peserta.

## kubectl dari laptopmu (opsional)
    kubectl --kubeconfig cka-p1.kubeconfig get nodes

Cluster-nya: https://157.10.160.102:6443 — alamat ini tetap selama kelas.
