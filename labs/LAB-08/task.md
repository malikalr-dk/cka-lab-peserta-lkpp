# LAB-08 — ConfigMaps, Secrets, dan Kendala Penjadwalan (Scheduling Constraints)

Tujuan: menyuntikkan konfigurasi aplikasi menggunakan `ConfigMap` dan `Secret` (baik sebagai *environment variables* maupun *mounted volume*), serta mengendalikan penempatan Pod ke node tertentu menggunakan `nodeSelector`, *taint*, dan *toleration* di namespace `cka-lab08`.

## Konteks & State Awal

- Namespace `cka-lab08` telah dibuat dalam keadaan kosong oleh skrip starter.
- Kluster memiliki dua node worker: `cka-pN-w1` dan `cka-pN-w2` (sesuaikan `pN` dengan nomor kluster Anda, periksa dengan `kubectl get nodes`).
- Gunakan image yang sudah tersedia secara lokal di containerd (mis. `nginx:1.27-alpine` atau `busybox:1.37` dengan perintah tidur) dan `imagePullPolicy: IfNotPresent`.

## Tugas

### Bagian 1: ConfigMap & Secret

1. Buat sebuah `ConfigMap` bernama `app-config` di namespace `cka-lab08` yang memiliki dua key:
   - Key `GREETING` dengan nilai `halo-cka`.
   - Key `app.properties` berupa isi file konfigurasi kecil yang memuat baris `mode=production`.
2. Buat sebuah `Secret` (`Opaque`) bernama `app-secret` di namespace `cka-lab08` dengan key `PASSWORD` bernilai `s3cr3t`.
3. Buat sebuah Pod bernama `config-demo` di namespace `cka-lab08` (pastikan terus berstatus `Running`, misalnya menggunakan image `nginx:1.27-alpine`) yang:
   - Mengonsumsi `ConfigMap` `app-config` sebagai *environment variable* (sehingga variabel lingkungan `GREETING=halo-cka` tersedia di dalam container).
   - Me-*mount* `ConfigMap` `app-config` sebagai volume pada path `/etc/app` (sehingga file `/etc/app/app.properties` tersedia di dalam container).
   - Mengonsumsi key `PASSWORD` dari `Secret` `app-secret` sebagai *environment variable* bernama `PASSWORD`.

### Bagian 2: Penjadwalan Pod (`nodeSelector` & `Taint`/`Toleration`)

1. Beri label `disk=fast` pada node worker pertama (`cka-pN-w1`).
2. Buat sebuah Pod bernama `sched-demo` di namespace `cka-lab08` yang menggunakan `nodeSelector` (`disk: fast`) sehingga dijadwalkan ke node `cka-pN-w1`.
3. Pasang *taint* `dedicated=lab:NoSchedule` pada node worker kedua (`cka-pN-w2`).
4. Buat sebuah Pod bernama `taint-demo` di namespace `cka-lab08` yang memiliki `tolerations` yang cocok terhadap taint `dedicated=lab:NoSchedule`, serta pastikan Pod tersebut dijadwalkan dan berjalan di node `cka-pN-w2`.
5. Buktikan penempatan ketiga Pod menggunakan `kubectl -n cka-lab08 get pods -o wide`.
