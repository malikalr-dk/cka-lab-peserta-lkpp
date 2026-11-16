# LAB-06 — Role-Based Access Control (RBAC)

Tujuan: RBAC least-privilege di `gisp-app` plus list nodes. Bukti: `kubectl auth can-i` sesuai matriks.

## Konteks & State Awal

- **Starter (wajib):** `bash starter/setup.sh` membuat ulang namespace `gisp-app` yang bersih dan menghapus `ClusterRole`/`ClusterRoleBinding` `dev-sa` sisa percobaan sebelumnya. Tanpa itu baseline bisa terbaca `PASS` duluan.

- Starter sudah bikin namespace `gisp-app`.
- Kerja dari laptop atau SSH ke `cka-pN-cp`.
- **Penting:** Terapkan prinsip *least privilege*. Jangan pernah menggunakan *wildcard* (`*`) pada `verbs` maupun `resources`, dan jangan mengikat `cluster-admin` ke `ServiceAccount` ini.

## Tugas

1. **Buat ServiceAccount `dev-sa`:**
   - Buat sebuah `ServiceAccount` bernama `dev-sa` di dalam namespace `gisp-app`.

2. **Role dan RoleBinding di namespace:**
   - Di dalam namespace `gisp-app`, buat sebuah `Role` yang mengizinkan verb `get`, `list`, dan `watch` **hanya** pada resource `pods`.
   - Ikat `Role` tersebut ke `ServiceAccount` `dev-sa` (namespace `gisp-app`) menggunakan sebuah `RoleBinding` di namespace `gisp-app`.
   - Buktikan izin cakupan namespace dengan `kubectl auth can-i` menggunakan identitas `system:serviceaccount:gisp-app:dev-sa`:
     - Membaca/melihat daftar pod di `gisp-app` harus menghasilkan `yes`.
     - Menghapus pod di `gisp-app`, membaca pod di namespace `default`, atau membaca `secrets` di `gisp-app` harus menghasilkan `no`.

3. **ClusterRole dan ClusterRoleBinding:**
   - Buat sebuah `ClusterRole` yang mengizinkan verb `list` **hanya** pada resource `nodes`.
   - Ikat `ClusterRole` tersebut ke `ServiceAccount` `dev-sa` (namespace `gisp-app`) menggunakan sebuah `ClusterRoleBinding`.
   - Buktikan dengan `kubectl auth can-i` bahwa `system:serviceaccount:gisp-app:dev-sa` dapat melakukan `list` pada `nodes` (`yes`), tetapi tetap tidak memiliki hak tulis atau akses berlebih lainnya.