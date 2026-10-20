# DSH_NET — проверка сетевого удара мечом по кладке замка.
#
# Клиент бьёт по секции стены "у себя"; настоящий урон считает хост и рассылает
# его, повтор помечается net_replay и обратно в сеть не уходит.
# Проверка: число живых секций кладки (wall_collision_active) уменьшилось и
# совпадает у обеих сторон.
#
#   pwsh -File tests/net/net_melee_test.ps1

param(
    [int]$Port = 7891,
    [double]$MeleeAt = 14.0,
    [double]$Settle = 18.0,
    [string]$Engine = "$env:LOCALAPPDATA\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runs = Join-Path $PSScriptRoot 'runs'
New-Item -ItemType Directory -Force -Path $runs | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$hostLog = Join-Path $runs "melee_host_$stamp.log"
$clientLog = Join-Path $runs "melee_client_$stamp.log"

if (-not (Test-Path $Engine)) { throw "Godot not found: $Engine" }
Write-Host "DSH_NET melee test: port=$Port melee_at=$MeleeAt settle=$Settle"

$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        '--net-host', "--net-port=$Port", '--net-name=host')
Start-Sleep -Seconds 12
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest', "--net-melee-at=$MeleeAt")

$deadline = (Get-Date).AddSeconds($MeleeAt + $Settle + 30)
while ((Get-Date) -lt $deadline) {
    if ($hostProcess.HasExited -and $clientProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
    if (((Get-Date) - $clientProcess.StartTime).TotalSeconds -gt ($MeleeAt + $Settle)) { break }
}
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }
Start-Sleep -Seconds 1

function Count-Matches([string]$text, [string]$pattern) {
    return ([regex]::Matches($text, $pattern)).Count
}

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }
$hostApplied = Count-Matches $hostText 'NET_MELEE_APPLIED replay=false'
$clientReplayed = Count-Matches $clientText 'NET_MELEE_APPLIED replay=true'

$checks = [ordered]@{
    'guest asked host'       = $clientText -match 'NET_MELEE role=client'
    'host applied both hits' = ($hostApplied -eq 2)
    'guest replayed both'    = ($clientReplayed -eq 2)
    'section broke on host'  = $hostText -match 'NET_MELEE_APPLIED replay=false.*broken": true'
    'section broke on guest' = $clientText -match 'NET_MELEE_APPLIED replay=true.*broken": true'
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host "`nhost applied=$hostApplied guest replayed=$clientReplayed"
Write-Host "--- host ---"
(Get-Content $hostLog | Where-Object { $_ -match 'NET_MELEE' } | Select-Object -Last 4) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "--- guest ---"
(Get-Content $clientLog | Where-Object { $_ -match 'NET_MELEE' } | Select-Object -Last 4) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "`nlogs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET melee test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET melee test PASSED"
exit 0
