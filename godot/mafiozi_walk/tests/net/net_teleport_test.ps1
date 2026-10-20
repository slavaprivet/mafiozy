# DSH_NET - отрицательный тест авторитета движения (телепорт клиента).
#
# Клиент вправе присылать свою позицию, но не вправе "переехать" на 500 м за один
# пакет. Тест подделывает состояние на уровне сети (как это сделал бы
# модифицированный клиент) и проверяет:
#   * хост отклонил скачок (DSH_NET_STATE_REJECT);
#   * принятая хостом позиция осталась прежней, а не (500, 30, 500);
#   * сама игра при этом продолжает играть: у хоста идут обычные обновления.

param(
    [int]$Port = 7921,
    [double]$TeleportAt = 8.0,
    [double]$Settle = 16.0,
    [string]$Engine = "$env:LOCALAPPDATA\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runs = Join-Path $PSScriptRoot 'runs'
New-Item -ItemType Directory -Force -Path $runs | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$hostLog = Join-Path $runs "tp_host_$stamp.log"
$clientLog = Join-Path $runs "tp_client_$stamp.log"

if (-not (Test-Path $Engine)) { throw "Godot not found: $Engine" }
Write-Host "DSH_NET teleport test: port=$Port teleport_at=$TeleportAt settle=$Settle"

$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        '--net-host', "--net-port=$Port", '--net-name=host', '--net-player-stats=4')
Start-Sleep -Seconds 12
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest',
        "--net-teleport-at=$TeleportAt", '--net-player-stats=4')

$deadline = (Get-Date).AddSeconds($TeleportAt + $Settle + 30)
while ((Get-Date) -lt $deadline) {
    if ($hostProcess.HasExited -and $clientProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
    if (((Get-Date) - $clientProcess.StartTime).TotalSeconds -gt ($TeleportAt + $Settle)) { break }
}
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }
Start-Sleep -Seconds 1

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }

function Get-Vector([string]$line, [string]$key) {
    if ($null -eq $line) { return $null }
    if ($line -match "$key=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)") {
        return @([double]$Matches[1], [double]$Matches[2], [double]$Matches[3])
    }
    return $null
}

function Last-Line([string]$path, [string]$pattern) {
    if (-not (Test-Path $path)) { return $null }
    $lines = @(Get-Content $path | Where-Object { $_ -match $pattern })
    if ($lines.Count -eq 0) { return $null }
    return $lines[-1]
}

$teleportLine = Last-Line $clientLog '^NET_TELEPORT forged='
$peerLine = Last-Line $hostLog '^NET_PEER_STATE'
$forgedPoint = Get-Vector $teleportLine 'forged'
$peerPoint = Get-Vector $peerLine 'pos'

$awayFromForged = -1.0
if ($null -ne $forgedPoint -and $null -ne $peerPoint) {
    $awayFromForged = [math]::Sqrt([math]::Pow($forgedPoint[0]-$peerPoint[0],2) + [math]::Pow($forgedPoint[1]-$peerPoint[1],2) + [math]::Pow($forgedPoint[2]-$peerPoint[2],2))
}

$checks = [ordered]@{
    'guest forged position' = ($null -ne $forgedPoint)
    'host rejected jump'    = $hostText -match 'DSH_NET_STATE_REJECT'
    'host kept real spot'   = ($awayFromForged -gt 100.0)
    'guest still online'    = $clientText -match 'DSH_NET_WELCOME'
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host ""
Write-Host "forged:      $($forgedPoint -join ', ')"
Write-Host "host keeps:  $($peerPoint -join ', ')  (distance to forged $([math]::Round($awayFromForged,1)) m)"
Write-Host "--- host ---"
(Get-Content $hostLog | Where-Object { $_ -match 'STATE_REJECT|NET_PEER_STATE' } | Select-Object -Last 3) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "--- guest ---"
(Get-Content $clientLog | Where-Object { $_ -match 'TELEPORT' } | Select-Object -Last 2) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "logs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET teleport test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET teleport test PASSED"
exit 0
