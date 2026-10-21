# DSH_NET — проверка сети двумя настоящими процессами Godot.
#
# Поднимает хост и клиента на localhost, ждёт, пока оба закончат, и проверяет
# журналы: подключение, состав, снапшоты, аватары и события должны дойти в обе
# стороны. Это не «юнит-тест на моках»: работают настоящие ENet-сокеты и
# настоящая сцена tests/net/net_test.tscn.
#
# Пример:
#   pwsh -File tests/net/net_pair_test.ps1
#   pwsh -File tests/net/net_pair_test.ps1 -Port 7844 -Hold 10

param(
    [int]$Port = 7831,
    [double]$Hold = 8.0,
    [string]$Engine = "$env:LOCALAPPDATA\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Scene = "res://tests/net/net_test.tscn"
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runs = Join-Path $PSScriptRoot 'runs'
New-Item -ItemType Directory -Force -Path $runs | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$hostLog = Join-Path $runs "host_$stamp.log"
$hostErr = Join-Path $runs "host_$stamp.err.log"
$clientLog = Join-Path $runs "client_$stamp.log"
$clientErr = Join-Path $runs "client_$stamp.err.log"

if (-not (Test-Path $Engine)) { throw "Godot not found: $Engine" }

Write-Host "DSH_NET test: port=$Port hold=$Hold project=$project"

$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError $hostErr `
    -ArgumentList @('--headless', '--path', $project, $Scene, '--',
        '--net-host', "--net-port=$Port", '--net-name=host',
        "--net-hold=$Hold")
Start-Sleep -Milliseconds 1200
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError $clientErr `
    -ArgumentList @('--headless', '--path', $project, $Scene, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest', "--net-hold=$Hold")

$deadline = (Get-Date).AddSeconds($Hold * 3 + 30)
while ((Get-Date) -lt $deadline) {
    $hostDone = $hostProcess.HasExited
    $clientDone = $clientProcess.HasExited
    if ($hostDone -and $clientDone) { break }
    Start-Sleep -Milliseconds 300
}
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }

$checks = [ordered]@{
    'host started'          = $hostText -match 'DSH_NET_HOST'
    'client started'        = $clientText -match 'DSH_NET_JOIN'
    'host saw peer'         = $hostText -match 'DSH_NET_PEER_JOINED'
    'client welcomed'       = $clientText -match 'DSH_NET_WELCOME'
    'host replicated guest' = $hostText -match 'avatars=1'
    'guest replicated host' = $clientText -match 'avatars=1'
    'host got event'        = $hostText -match 'events_in=[1-9]'
    'guest got host event'  = $clientText -match 'DSH_NET_SYNC_PEER_JOINED|NET_TEST_EVENT'
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host "`n--- host summary ---"
($hostText -split "`n" | Where-Object { $_ -match 'NET_TEST_SUMMARY|DSH_NET_PEER_JOINED|DSH_NET_SYNC_PEER_JOINED' }) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "--- guest summary ---"
($clientText -split "`n" | Where-Object { $_ -match 'NET_TEST_SUMMARY|DSH_NET_WELCOME|NET_TEST_EVENT|DSH_NET_AVATAR_SPAWN' }) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "`nlogs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET test PASSED"
exit 0
