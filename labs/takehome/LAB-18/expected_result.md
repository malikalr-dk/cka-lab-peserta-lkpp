# Expected Result — LAB-18

State akhir yang dinilai `verify/verify.sh` di node `cka-pN-cp`. Verifier menilai perilaku,
bukan nama image: state yang sama berlaku untuk `podinfo:6.7.1` dan untuk image BYO
(`/root/lab/lab18-image.txt`).

1. **Ketersediaan metrics API:**
   - `kubectl -n cka-lab18 top pods` (atau `kubectl top nodes` sebagai fallback) mengembalikan baris
     metrik CPU/memori, dengan retry berbatas 60 detik.

2. **`Deployment` `demo` Ready + `requests.cpu`:**
   - `status.readyReplicas` sama dengan `spec.replicas` (minimal `1`) dalam retry berbatas 60 detik.
   - `resources.requests.cpu` pada container terisi (mis. `100m`). Nilainya tidak dikunci, tetapi
     field harus ada. Tanpa itu HPA tidak bisa menghitung persentase.

3. **Objek `HorizontalPodAutoscaler` `demo`:**
   - Menargetkan `Deployment/demo`, dengan `minReplicas: 1`, `maxReplicas: 4`, dan target utilisasi
     CPU rata-rata `50%` (autoscaling/v2 `metrics[0].resource.target.averageUtilization`, atau field
     v1 `targetCPUUtilizationPercentage`).

4. **Bukti scale-out (perilaku):**
   - Di bawah beban 4 loop `wget` paralel yang dijalankan verifier (`lab18-verify-load`),
     `status.readyReplicas` pada `Deployment` `demo` menjadi `> 1` dalam jendela **180 detik** sejak
     beban mulai (polling tiap 3 detik, 60 percobaan).

5. **Bukti scale-in (perilaku):**
   - Setelah verifier menghapus Pod bebannya sendiri **dan** `load-generator` milik peserta,
     `readyReplicas` kembali ke `1` dalam jendela **120 detik** (polling tiap 3 detik, 40 percobaan).
   - Jendela 120 detik hanya tercapai karena `task.md` langkah 3 mewajibkan
     `behavior.scaleDown.stabilizationWindowSeconds: 10`; jendela stabilisasi default `300` detik
     akan melewati batas ini. Verifier tidak mengunci field `behavior` itu sendiri; yang dinilai
     adalah perilakunya.

**Output verifier:**
- Menjalankan `verify/verify.sh` mencetak 5 baris `PASS:` dan diakhiri `RESULT: PASS (5/5)` dengan
  kode keluar `0`.

State awal (sebelum peserta mengerjakan) menghasilkan `RESULT: FAIL (2/5)`: metrics API dan
`Deployment` Ready + `requests.cpu` PASS, HPA, bukti scale-out, dan bukti scale-in FAIL. Assertion 4
dan 5 tidak menunggu jendela penuh saat objeknya belum ada. Keduanya langsung menjawab dengan pesan
`not attempted: HPA or Deployment missing`, jadi state awal selesai dalam hitungan detik.

Verifier tidak pernah meng-assert nama image; image hanya dicetak sebagai baris `INFO`.