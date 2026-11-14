# Expected Result — LAB-09

State akhir yang dinilai `verify/verify.sh` di node `cka-pN-cp`. Verifier bersifat **behaviour-based**:
nama image tidak pernah di-assert, sehingga kelas boleh memakai image sendiri lewat
`/root/lab/lab09-image.txt` (lihat `task.md` bagian BYO).

1. **Deployment `demo` siap**
   - `cka-lab09/demo` punya `readyReplicas=1` (`1/1`).
   - Image default `docker.io/stefanprodan/podinfo:6.7.1`, `imagePullPolicy: IfNotPresent`,
     `containerPort: 9898`, label Pod `app=demo`. Nilai ini tidak dinilai verifier.

2. **Service `demo`**
   - Bertipe `ClusterIP`, mendapat `clusterIP` yang dialokasikan (bukan `None`).
   - Melayani port yang dideklarasikan: `9898` saat memakai default.

3. **Endpoints / EndpointSlice**
   - Objek `Endpoints demo` (atau `EndpointSlice` berlabel `kubernetes.io/service-name=demo`)
     memuat minimal satu alamat Pod siap pakai.

4. **DNS dari dalam Pod**
   - `nslookup demo.cka-lab09.svc.cluster.local` dari pod `client` (`busybox:1.37`) mengembalikan
     minimal satu A record.

5. **HTTP dari dalam Pod**
   - `wget -S -O /dev/null` ke `http://demo.cka-lab09.svc.cluster.local:9898/healthz` mengembalikan
     status `200`.

## Output verifier saat PASS

```
INFO: /root/lab/lab09-image.txt tidak ada -> default image=docker.io/stefanprodan/podinfo:6.7.1 port=9898 path=/healthz
INFO: Deployment cka-lab09/demo memakai image docker.io/stefanprodan/podinfo:6.7.1 (nama image tidak dinilai)
PASS: Deployment 'cka-lab09/demo' has readyReplicas=1 (expected: 1 ready replica)
PASS: Service 'cka-lab09/demo' has type=ClusterIP, clusterIP=10.96.12.34, port=9898 (expected: ClusterIP on port 9898)
PASS: Endpoints for Service 'cka-lab09/demo' list 1 ready address(es) [10.244.1.9] (expected: >=1 ready address)
PASS: DNS lookup 'demo.cka-lab09.svc.cluster.local' from pod 'cka-lab09/client' resolved [10.96.12.34] (expected: >=1 A record)
PASS: HTTP GET 'http://demo.cka-lab09.svc.cluster.local:9898/healthz' from pod 'cka-lab09/client' returned 200 (expected: HTTP 200)
RESULT: PASS (5/5)
```

Nilai `clusterIP` dan alamat Pod selalu berbeda antar kluster; yang dibandingkan adalah bentuk
barisnya, bukan angkanya.

## Output verifier saat state awal (FAIL yang diharapkan)

```
INFO: /root/lab/lab09-image.txt tidak ada -> default image=docker.io/stefanprodan/podinfo:6.7.1 port=9898 path=/healthz
INFO: Deployment cka-lab09/demo memakai image docker.io/stefanprodan/podinfo:6.7.1 (nama image tidak dinilai)
PASS: Deployment 'cka-lab09/demo' has readyReplicas=1 (expected: 1 ready replica)
FAIL: Service 'cka-lab09/demo' has type=missing, clusterIP=missing, port=missing (expected: ClusterIP on port 9898)
FAIL: Endpoints for Service 'cka-lab09/demo' list 0 addresses [none] (expected: >=1 ready address)
FAIL: DNS lookup 'demo.cka-lab09.svc.cluster.local' from pod 'cka-lab09/client' did not resolve (expected: >=1 A record)
FAIL: HTTP GET 'http://demo.cka-lab09.svc.cluster.local:9898/healthz' from pod 'cka-lab09/client' returned HTTP 000 (expected: HTTP 200)
RESULT: FAIL (1/5)
```

Exit code `1`. Setiap loop retry di-gate pada keberadaan objek (`ptries`), jadi state awal gagal
dalam hitungan detik, bukan menunggu 5×30 detik.

## Varian BYO

Dengan `/root/lab/lab09-image.txt` berisi `image=.../api:1.4.2`, `port=8080`, `path=/healthz`, baris
yang berubah hanya angka port dan URL pada pemeriksaan 2 dan 5 (mis.
`http://demo.cka-lab09.svc.cluster.local:8080/healthz`), dan `RESULT: PASS (5/5)` tetap sama.
Deklarasi yang tidak lengkap menambah satu baris `FAIL:` di depan (denominator menjadi `6`), dan
verifier melanjutkan dengan default.

## Catatan kebersihan

- Verifier hanya memakai pod `client` milik starter. Kalau pod itu hilang, verifier membuat pod
  sementara `lab09-verify-probe` dan menghapusnya lagi lewat `trap ... EXIT`.
- `reset/reset.sh` menghapus namespace lalu menjalankan `starter/setup.sh`, sehingga sisa Service
  atau pod probe dari percobaan sebelumnya tidak terbawa.
