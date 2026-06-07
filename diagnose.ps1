$services = @("vmcompute", "vmms", "LxssManager")
foreach ($s in $services) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "$($svc.Name): $($svc.Status) (StartType: $($svc.StartType))"
    } else {
        Write-Host "$s : NOT FOUND"
    }
}

$distros = @(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue)
Write-Host "WSL registry entries: $($distros.Count)"

$hns = @(Get-HnsNetwork -ErrorAction SilentlyContinue | Where-Object { $_.Type -eq "ICS" } | Select-Object ID, Name, Type)
Write-Host "HNS Networks: $($hns.Count)"
foreach ($n in $hns) { Write-Host "  $($n.ID) - $($n.Name)" }

$netAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*WSL*' -or $_.InterfaceDescription -like '*Hyper-V*' } | Select-Object Name, Status, InterfaceDescription
Write-Host "Network adapters: $($netAdapters.Count)"
foreach ($a in $netAdapters) { Write-Host "  $($a.Name) - $($a.Status)" }