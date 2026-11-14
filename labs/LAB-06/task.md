# LAB-06 — Role-Based Access Control (RBAC)

Tujuan: mengonfigurasi kontrol akses berbasis peran (*least-privilege*) menggunakan `ServiceAccount`, `Role`, `RoleBinding` (cakupan namespace `cka-lab06`), serta `ClusterRole` dan `ClusterRoleBinding` (cakupan kluster), lalu membuktikan izinnya menggunakan `kubectl auth can-i`.

## Konteks & State Awal

- Namespace `cka-lab06` telah disiapkan oleh skrip starter.
- Anda dapat bekerja dari laptop maupun melalui SSH di `cka-pN-cp`.
- **Penting:** Terapkan prinsip *least privilege*. Jangan pernah menggunakan *wildcard* (`*`) pada `verbs` maupun `resources`, dan jangan mengikat `cluster-admin` ke `ServiceAccount` ini.

## Tugas

1. **ServiceAccount:**
   - Buat sebuah `ServiceAccount` bernama `dev-sa` di dalam namespace `cka-lab06`.

2. **Akses Cakupan Namespace (`Role` & `RoleBinding`):**
   - Di dalam namespace `cka-lab06`, buat sebuah `Role` yang mengizinkan verb `get`, `list`, dan `watch` **hanya** pada resource `pods`.
   - Ikat `Role` tersebut ke `ServiceAccount` `dev-sa` (namespace `cka-lab06`) menggunakan sebuah `RoleBinding` di namespace `cka-lab06`.
   - Buktikan izin cakupan namespace dengan `kubectl auth can-i` menggunakan identitas `system:serviceaccount:cka-lab06:dev-sa`:
     - Membaca/melihat daftar pod di `cka-lab06` harus menghasilkan `yes`.
     - Menghapus pod di `cka-lab06`, membaca pod di namespace `default`, atau membaca `secrets` di `cka-lab06` harus menghasilkan `no`.

3. **Akses Cakupan Kluster (`ClusterRole` & `ClusterRoleBinding`):**
   - Buat sebuah `ClusterRole` yang mengizinkan verb `list` **hanya** pada resource `nodes`.
   - Ikat `ClusterRole` tersebut ke `ServiceAccount` `dev-sa` (namespace `cka-lab06`) menggunakan sebuah `ClusterRoleBinding`.
   - Buktikan dengan `kubectl auth can-i` bahwa `system:serviceaccount:cka-lab06:dev-sa` dapat melakukan `list` pada `nodes` (`yes`), tetapi tetap tidak memiliki hak tulis atau akses berlebih lainnya.
