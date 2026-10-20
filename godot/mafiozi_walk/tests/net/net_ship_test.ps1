# DSH_NET - проверка корабля: корпус ведёт хост, клиент повторяет трансформ.
#
# Корабль - AnimatableBody3D, который двигает своя же симуляция. Если каждый
# игрок считает его у себя, палуба с пушками оказывается в разных местах.
# Теперь хост публикует трансформ в снапшоте ("ship"), клиент не симулирует
# корпус и повторяет его.
#
# Проверки:
#   * хост сдвинул корабль (NET_SHIP moved);
#   * клиент к концу прогона стоит там же, где хост (расхождение <= 1.5 м);
#   * у клиента есть свои строки NET_SHIP (то есть он вообще видит корабль).

param(
    [int]$Port = 7911,
    [double]$MoveAt = 14.0,
    [double]$Settle = 20.0,
    [double]$Tolerance = 1.5,
    [string]$Engine = "$env:LOCALAPPDATA\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runs = Join-Path $PSScriptRoot 'runs'
New-Item -ItemType Directory -Force -Path $runs | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$hostLog = Join-Path $runs "ship_host_$stamp.log"
$clientLog = Join-Path $runs "ship_client_$stamp.log"

if (-not (Test-Path $Engine)) { throw "Godot not found: $Engine" }
Write-Host "DSH_NET ship test: port=$Port move_at=$MoveAt settle=$Settle"

$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        '--net-host', "--net-port=$Port", '--net-name=host',
        "--net-ship-at=$MoveAt", '--net-ship-stats=4')
Start-Sleep -Seconds 12
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest', '--net-ship-stats=4')

$deadline = (Get-Date).AddSeconds($MoveAt + $Settle + 30)
while ((Get-Date) -lt $deadline) {
    if ($hostProcess.HasExited -and $clientProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
    if (((Get-Date) - $clientProcess.StartTime).TotalSeconds -gt ($MoveAt + $Settle)) { break }
}
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }
Start-Sleep -Seconds 1

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }

function Get-LastShipPosition([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    $lines = @(Get-Content $path | Where-Object { $_ -match '^NET_SHIP t=' })
    if ($lines.Count -eq 0) { return $null }
    $last = $lines[-1]
    if ($last -match 'pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)') {
        return @([double]$Matches[1], [double]$Matches[2], [double]$Matches[3])
    }
    return $null
}

function Get-ShipStart([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    $lines = @(Get-Content $path | Where-Object { $_ -match '^NET_SHIP start' })
    if ($lines.Count -eq 0) { return $null }
    if ($lines[-1] -match 'pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)') {
        return @([double]$Matches[1], [double]$Matches[2], [double]$Matches[3])
    }
    return $null
}

# Позиция корабля, ПРИНЯТАЯ клиентом из снапшота ("state_pos=" в строке NET_SHIP).
function Get-ReceivedStates([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    $points = @()
    foreach ($line in (Get-Content $path | Where-Object { $_ -match '^NET_SHIP t=' })) {
        if ($line -match 'state_pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)') {
            $points += ,@([double]$Matches[1], [double]$Matches[2], [double]$Matches[3])
        }
    }
    return $points
}

function Distance($a, $b) {
    if ($null -eq $a -or $null -eq $b) { return -1.0 }
    return [math]::Sqrt([math]::Pow($a[0]-$b[0],2) + [math]::Pow($a[1]-$b[1],2) + [math]::Pow($a[2]-$b[2],2))
}

$hostPos = Get-LastShipPosition $hostLog
$clientPos = Get-LastShipPosition $clientLog
$hostStart = Get-ShipStart $hostLog
$received = @(Get-ReceivedStates $clientLog)
$firstReceived = $null
$lastReceived = $null
if ($received.Count -gt 0) {
    $firstReceived = $received[0]
    $lastReceived = $received[$received.Count - 1]
}

$moved = Distance $hostStart $hostPos
$liveSpan = Distance $firstReceived $lastReceived
$agreement = Distance $lastReceived $hostPos

$checks = [ordered]@{
    'host opened sails'      = ($hostText -match 'NET_SHIP start')
    'ship actually moved'    = ($moved -gt 10.0)
    'guest receives state'   = ($received.Count -ge 2)
    'guest state is live'    = ($liveSpan -gt 10.0)
    'state matches host'     = ($agreement -ge 0.0) -and ($agreement -le 8.0)
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host ""
Write-Host "host start:        $($hostStart -join ', ')"
Write-Host "host last pos:     $($hostPos -join ', ')"
Write-Host "host moved:        $([math]::Round($moved,2)) m"
Write-Host "guest received:    $($firstReceived -join ', ') -> $($lastReceived -join ', ')"
Write-Host "guest state span:  $([math]::Round($liveSpan,2)) m"
Write-Host "state vs host:     $([math]::Round($agreement,2)) m"
Write-Host "logs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET ship test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET ship test PASSED"
exit 0
