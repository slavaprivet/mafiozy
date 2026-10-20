# DSH_NET — проверка этапа 2: снаряд-дубль чужого выстрела.
#
# Хост и гость поднимают настоящий замок с кораблём. Оба по таймеру стреляют из
# корабельной пушки. По сети идёт одно событие запуска, вторая сторона поднимает
# из своего пула снаряд-дубль: он летит и даёт эффекты, но не наносит урон
# (урон и разрушение остаются за владельцем выстрела).
#
# Проверка: у каждого процесса есть и `DSH_NET_SHOT_SENT` (свой выстрел), и
# `DSH_NET_SHOT_PROXY` (дубль чужого).
#
#   pwsh -File tests/net/net_projectile_test.ps1

param(
    [int]$Port = 7881,
    [double]$ShotAt = 16.0,
    [double]$Settle = 30.0,
    [string]$Engine = "$env:LOCALAPPDATA\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runs = Join-Path $PSScriptRoot 'runs'
New-Item -ItemType Directory -Force -Path $runs | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$hostLog = Join-Path $runs "shot_host_$stamp.log"
$clientLog = Join-Path $runs "shot_client_$stamp.log"

if (-not (Test-Path $Engine)) { throw "Godot not found: $Engine" }
Write-Host "DSH_NET projectile test: port=$Port shot_at=$ShotAt settle=$Settle"

$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        '--net-host', "--net-port=$Port", '--net-name=host', "--net-shot-at=$ShotAt")
Start-Sleep -Seconds 12
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest', "--net-shot-at=$ShotAt")

$deadline = (Get-Date).AddSeconds($ShotAt + $Settle + 30)
while ((Get-Date) -lt $deadline) {
    if ($hostProcess.HasExited -and $clientProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
    if (((Get-Date) - $clientProcess.StartTime).TotalSeconds -gt ($ShotAt + $Settle)) { break }
}
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }
Start-Sleep -Seconds 1

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }

$checks = [ordered]@{
    'host fired'          = $hostText -match 'DSH_NET_SHOT_SENT'
    'guest fired'         = $clientText -match 'DSH_NET_SHOT_SENT'
    'host got guest ball' = $hostText -match 'DSH_NET_SHOT_PROXY'
    'guest got host ball' = $clientText -match 'DSH_NET_SHOT_PROXY'
    'guest still online'  = $clientText -match 'DSH_NET_WELCOME'
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host "--- host ---"
(Get-Content $hostLog | Where-Object { $_ -match 'NET_SHOT|PEER_JOINED' } | Select-Object -Last 5) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "--- guest ---"
(Get-Content $clientLog | Where-Object { $_ -match 'NET_SHOT|WELCOME' } | Select-Object -Last 5) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "`nlogs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET projectile test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET projectile test PASSED"
exit 0
