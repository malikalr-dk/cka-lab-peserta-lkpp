# Lab CKA — p1
## Masuk (sekali)
    bash lab-hosts.sh        # Linux/macOS, butuh sudo
    powershell -ExecutionPolicy Bypass -File .\lab-hosts.ps1   # Windows, PowerShell as Admin
## Pakai
    ssh lab01
## Lab
    ls /opt/lab/labs
    bash /opt/lab/labs/LAB-NN/verify/verify.sh    # PASS (n/n) = selesai
    bash /opt/lab/labs/LAB-NN/reset/reset.sh      # ulangi dari state bersih
## Aturan
1. `kubeadm reset` hanya di LAB-03.
2. Jangan sentuh `kube-system`.
3. Cluster rusak: panggil trainer.
