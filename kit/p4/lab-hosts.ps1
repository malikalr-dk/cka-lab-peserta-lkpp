# lab-hosts.ps1 — sekali jalan: daftarkan lab04 -> 157.10.160.158 di hosts. PowerShell as Admin.
#   powershell -ExecutionPolicy Bypass -File .\lab-hosts.ps1
$ErrorActionPreference = "Stop"
$Ip    = if ($env:LAB_IP)    { $env:LAB_IP }    else { "157.10.160.158" }
$Name  = if ($env:LAB_NAME)  { $env:LAB_NAME }  else { "lab04" }
$Hosts = if ($env:LAB_HOSTS) { $env:LAB_HOSTS } else { Join-Path $env:SystemRoot "System32\drivers\etc\hosts" }
$Begin = "# >>> CKA lab (dikelola lab-hosts.ps1)"
$End   = "# <<< CKA lab"

# hosts file cuma bisa ditulis Administrator. Cek elevasi dulu — percobaan tulis langsung
# menghasilkan IOException mentah yang bikin peserta bingung.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Error "butuh Administrator: tutup ini, buka PowerShell as Administrator, lalu ulangi."
  exit 1
}

$keep = New-Object System.Collections.Generic.List[string]
$inBlock = $false
foreach ($l in (Get-Content -LiteralPath $Hosts -ErrorAction SilentlyContinue)) {
  if ($l -eq $Begin) { $inBlock = $true; continue }
  if ($l -eq $End)   { $inBlock = $false; continue }
  if (-not $inBlock) { $keep.Add($l) }
}
$keep.Add($Begin); $keep.Add("$Ip $Name"); $keep.Add($End)
# Set-Content gagal di Windows 11 PS 5.1 dengan "Stream was not readable" untuk hosts file;
# WriteAllLines menulis langsung dan sudah terbukti jalan sebagai Administrator.
[IO.File]::WriteAllLines($Hosts, $keep, (New-Object System.Text.ASCIIEncoding))

Write-Host "ok: ssh root@$Name -> $Ip"
if (-not (Select-String -LiteralPath $Hosts -Pattern "^\s*$([regex]::Escape($Ip))\s+$([regex]::Escape($Name))\s*$" -Quiet)) {
  Write-Warning "$Name belum muncul di $Hosts"
}
