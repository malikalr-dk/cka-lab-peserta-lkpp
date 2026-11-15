# LAB-06 — Role-Based Access Control (RBAC)

Tujuan: RBAC least-privilege di `cka-lab06` plus list nodes. Bukti: `kubectl auth can-i` sesuai matriks.

## Konteks & State Awal

- Starter sudah bikin namespace `cka-lab06`.
- Kerja dari laptop atau SSH ke `cka-pN-cp`.
- **Penting:** Terapkan prinsip *least privilege*. Jangan pernah menggunakan *wildcard* (`*`) pada `verbs` maupun `resources`, dan jangan mengikat `cluster-admin` ke `ServiceAccount` ini.

## Tugas

1. **Buat ServiceAccount `dev-sa`:**
   - Buat sebuah `ServiceAccount` bernama `dev-sa` di dalam namespace `cka-lab06`.

2. **Role dan RoleBinding di namespace:**
   - Di dalam namespace `cka-lab06`, buat sebuah `Role` yang mengizinkan verb `get`, `list`, dan `watch` **hanya** pada resource `pods`.
   - Ikat `Role` tersebut ke `ServiceAccount` `dev-sa` (namespace `cka-lab06`) menggunakan sebuah `RoleBinding` di namespace `cka-lab06`.
   - Buktikan izin cakupan namespace dengan `kubectl auth can-i` menggunakan identitas `system:serviceaccount:cka-lab06:dev-sa`:
     - Membaca/melihat daftar pod di `cka-lab06` harus menghasilkan `yes`.
     - Menghapus pod di `cka-lab06`, membaca pod di namespace `default`, atau membaca `secrets` di `cka-lab06` harus menghasilkan `no`.

3. **ClusterRole dan ClusterRoleBinding:**
   - Buat sebuah `ClusterRole` yang mengizinkan verb `list` **hanya** pada resource `nodes`.
   - Ikat `ClusterRole` tersebut ke `ServiceAccount` `dev-sa` (namespace `cka-lab06`) menggunakan sebuah `ClusterRoleBinding`.
   - Buktikan dengan `kubectl auth can-i` bahwa `system:serviceaccount:cka-lab06:dev-sa` dapat melakukan `list` pada `nodes` (`yes`), tetapi tetap tidak memiliki hak tulis atau akses berlebih lainnya.