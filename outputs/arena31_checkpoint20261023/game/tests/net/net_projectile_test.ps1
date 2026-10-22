# DSH_NET - проверка этапа 2: снаряд-дубль чужого выстрела (усиленная).
#
# Хост и гость поднимают настоящий замок с кораблём и стреляют из корабельной
# пушки в БОКОВУЮ стену замка. Цели разные (хост z=12, гость z=40), поэтому
# сравнение "свой выстрел против дубля" действительно что-то доказывает.
#
# Проверяется не наличие строк в логе, а результат:
#   1) траектории: точки своего ядра и дубля на чужой стороне совпадают по
#      одинаковым возрастным отсечкам (0.25 с) с допуском 0.35 м;
#   2) двойного урона нет: мгновенный урон каждого взрыва (`dead=` из
#      NET_EXPLOSION) совпадает у обеих сторон, взрывов ровно два;
#   3) клиент остался онлайн: heartbeat идёт до конца прогона, обрыва нет.

param(
    [int]$Port = 7881,
    [double]$ShotAt = 14.0,
    [double]$Settle = 26.0,
    [double]$Tolerance = 0.35,
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
Write-Host "DSH_NET projectile test: port=$Port shot_at=$ShotAt settle=$Settle tol=$Tolerance"

$common = @('--net-ball-trace', '--net-heartbeat=3', '--net-castle-stats=4')
$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" `
    -ArgumentList (@('--headless', '--path', $project, '--', '--net-host',
        "--net-port=$Port", '--net-name=host', "--net-shot-at=$ShotAt") + $common)
Start-Sleep -Seconds 12
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" `
    -ArgumentList (@('--headless', '--path', $project, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest', "--net-shot-at=$ShotAt") + $common)

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

# --- траектории -------------------------------------------------------------
function Get-Traces([string]$path) {
    $map = @{}
    if (-not (Test-Path $path)) { return $map }
    foreach ($line in (Get-Content $path | Where-Object { $_ -match 'NET_BALL_TRACE' })) {
        if ($line -match 'shot=(\d+) proxy=(true|false) bucket=(\d+) pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)') {
            $key = "shot$($Matches[1])-proxy$($Matches[2])"
            if (-not $map.ContainsKey($key)) { $map[$key] = @{} }
            $map[$key][[int]$Matches[3]] = @([double]$Matches[4], [double]$Matches[5], [double]$Matches[6])
        }
    }
    return $map
}

$hostTraces = Get-Traces $hostLog
$clientTraces = Get-Traces $clientLog

$pairs = @(
    @{ Own = $hostTraces['shot1-proxyfalse']; Proxy = $clientTraces['shot1-proxytrue'] },
    @{ Own = $clientTraces['shot1-proxyfalse']; Proxy = $hostTraces['shot1-proxytrue'] }
)
$bestMatched = 0
$bestWorstDelta = [double]::MaxValue
foreach ($pair in $pairs) {
    $own = $pair.Own; $proxy = $pair.Proxy
    if ($null -eq $own -or $null -eq $proxy) { continue }
    $matched = 0
    $worst = 0.0
    foreach ($bucket in $own.Keys) {
        if (-not $proxy.ContainsKey($bucket)) { continue }
        $a = $own[$bucket]; $b = $proxy[$bucket]
        $delta = [math]::Sqrt([math]::Pow($a[0]-$b[0],2) + [math]::Pow($a[1]-$b[1],2) + [math]::Pow($a[2]-$b[2],2))
        $matched++
        if ($delta -gt $worst) { $worst = $delta }
    }
    if ($matched -gt $bestMatched) { $bestMatched = $matched; $bestWorstDelta = $worst }
}

# --- урон -------------------------------------------------------------------
function Get-LastStat([string]$path, [string]$name) {
    if (-not (Test-Path $path)) { return -1 }
    $lines = Get-Content $path | Where-Object { $_ -match 'NET_CASTLE' }
    if (-not $lines) { return -1 }
    if ($lines[-1] -match "$name=(-?\d+)") { return [int]$Matches[1] }
    return -1
}

function Get-ExplosionBricks([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    $counts = @()
    foreach ($line in (Get-Content $path | Where-Object { $_ -match 'NET_EXPLOSION ' })) {
        if ($line -match 'dead=(\d+)') { $counts += [int]$Matches[1] }
    }
    return $counts
}

$hostBricks = @(Get-ExplosionBricks $hostLog)
$clientBricks = @(Get-ExplosionBricks $clientLog)
$hostSorted = ($hostBricks | Sort-Object) -join ','
$clientSorted = ($clientBricks | Sort-Object) -join ','
$hostExplosions = Get-LastStat $hostLog 'explosions'
$clientExplosions = Get-LastStat $clientLog 'explosions'
$hostDetached = Get-LastStat $hostLog 'detached'

# --- клиент остался онлайн --------------------------------------------------
$clientHeartbeats = @()
if (Test-Path $clientLog) {
    $clientHeartbeats = Get-Content $clientLog | Where-Object { $_ -match 'NET_HEARTBEAT role=client' }
}
$lastHeartbeatT = -1
if ($clientHeartbeats.Count -gt 0 -and $clientHeartbeats[-1] -match 't=(\d+)') { $lastHeartbeatT = [int]$Matches[1] }
$lastCastleT = -1
if (Test-Path $clientLog) {
    $castleLines = Get-Content $clientLog | Where-Object { $_ -match 'NET_CASTLE' }
    if ($castleLines.Count -gt 0 -and $castleLines[-1] -match 't=(\d+)') { $lastCastleT = [int]$Matches[1] }
}
$heartbeatCount = $clientHeartbeats.Count

$checks = [ordered]@{
    'host fired'                = $hostText -match 'DSH_NET_SHOT_SENT'
    'guest fired'               = $clientText -match 'DSH_NET_SHOT_SENT'
    'host got guest ball'       = $hostText -match 'DSH_NET_SHOT_PROXY'
    'guest got host ball'       = $clientText -match 'DSH_NET_SHOT_PROXY'
    'trajectories sampled'      = ($hostTraces.Count -gt 0) -and ($clientTraces.Count -gt 0)
    'trajectories match'        = ($bestMatched -ge 3) -and ($bestWorstDelta -le $Tolerance)
    'ball actually hit masonry' = ($hostDetached -gt 0)
    'explosions equal'          = ($hostExplosions -gt 0) -and ($hostExplosions -eq $clientExplosions)
    'two explosions only'       = ($hostBricks.Count -eq 2) -and ($clientBricks.Count -eq 2)
    'same instant damage'       = ($hostBricks.Count -gt 0) -and ($hostSorted -eq $clientSorted)
    'client stayed online'      = ($heartbeatCount -ge 5) -and ($lastHeartbeatT -ge ($lastCastleT - 6)) -and ($lastCastleT -gt 0) -and ($clientText -notmatch 'DSH_NET_SERVER_DISCONNECTED')
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host ""
Write-Host "trace points matched=$bestMatched worst_delta=$([math]::Round($bestWorstDelta,3)) m"
Write-Host "explosions host=$hostExplosions guest=$clientExplosions; bricks per explosion host=[$hostSorted] guest=[$clientSorted]"
Write-Host "last guest heartbeat t=$lastHeartbeatT s; detached at stop host=$hostDetached"
Write-Host "--- host ---"
(Get-Content $hostLog | Where-Object { $_ -match 'NET_SHOT|NET_EXPLOSION|NET_CASTLE' } | Select-Object -Last 4) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "--- guest ---"
(Get-Content $clientLog | Where-Object { $_ -match 'NET_SHOT|NET_EXPLOSION|NET_CASTLE' } | Select-Object -Last 4) | ForEach-Object { Write-Host $_.Trim() }
Write-Host ""
Write-Host "logs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET projectile test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET projectile test PASSED"
exit 0
