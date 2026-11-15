# LAB-08 — ConfigMaps, Secrets, dan Kendala Penjadwalan (Scheduling Constraints)

Tujuan: suntik `ConfigMap`/`Secret` ke pod (env dan volume) serta arahkan penjadwalan dengan `nodeSelector`, taint, dan toleration di `gisp-app`.

## Konteks & State Awal

- Starter sudah bikin namespace `gisp-app` dalam keadaan kosong.
- Kluster punya dua worker: `cka-pN-w1` dan `cka-pN-w2` (ganti `pN` sesuai clustermu; cek `kubectl get nodes`).
- Pakai image lokal di `containerd` (mis. `nginx:1.27-alpine` atau `busybox:1.37` dengan sleep) dan `imagePullPolicy: IfNotPresent`.

## Tugas

### Bagian 1: ConfigMap & Secret

1. Buat `ConfigMap` `app-config` di `gisp-app` dengan dua key:
   - Key `GREETING` bernilai `halo-cka`.
   - Key `app.properties` berisi config kecil dengan baris `mode=production`.
2. Buat `Secret` (`Opaque`) `app-secret` di `gisp-app` dengan key `PASSWORD` = `s3cr3t`.
3. Buat pod `config-demo` di `gisp-app` (tetap `Running`, mis. image `nginx:1.27-alpine`) yang:
   - Memuat `ConfigMap` `app-config` sebagai *environment variable* (`GREETING=halo-cka` di container).
   - Mount `ConfigMap` `app-config` ke `/etc/app` (file `/etc/app/app.properties` ada di container).
   - Memuat key `PASSWORD` dari `Secret` `app-secret` sebagai env `PASSWORD`.

### Bagian 2: Penjadwalan Pod (`nodeSelector` & `Taint`/`Toleration`)

1. Tambah label `disk=fast` pada worker pertama (`cka-pN-w1`).
2. Buat pod `sched-demo` di `gisp-app` dengan `nodeSelector` `disk: fast` agar masuk ke `cka-pN-w1`.
3. Pasang taint `dedicated=lab:NoSchedule` pada worker kedua (`cka-pN-w2`).
4. Buat pod `taint-demo` di `gisp-app` dengan `tolerations` yang cocok ke taint itu; pastikan pod jalan di `cka-pN-w2`.
5. Buktikan penempatan ketiga pod lewat `kubectl -n gisp-app get pods -o wide`.