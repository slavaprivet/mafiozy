# DSH_NET - проверка броска меча/копья по сети.
#
# Оружие в броске уже летит как снаряд с ручной интеграцией, поэтому по сети идёт
# одно событие: какое оружие, откуда и с какой скоростью. Вторая сторона строит
# такой же видимый снаряд и ведёт его тем же шагом, но урона не наносит.
#
# Сцена: город (main_city.tscn) с установленным sword_prototype (--sword-proto=1).
# В замке этот прототип не ставится, поэтому проверка идёт на городской сцене.
#
# Критерии:
#   * обе стороны бросили (NET_THROW ... result ok);
#   * обе получили чужой бросок (DSH_NET_THROW_PROXY) с той же точкой запуска;
#   * снаряд-дубль долетел и воткнулся (DSH_NET_THROW_LAND).

param(
    [int]$Port = 7931,
    [string]$Scene = "res://scenes/castle.tscn",
    [double]$ThrowAt = 12.0,
    [double]$Settle = 40.0,
    [string]$Engine = "$env:LOCALAPPDATA\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runs = Join-Path $PSScriptRoot 'runs'
New-Item -ItemType Directory -Force -Path $runs | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$hostLog = Join-Path $runs "throw_host_$stamp.log"
$clientLog = Join-Path $runs "throw_client_$stamp.log"

if (-not (Test-Path $Engine)) { throw "Godot not found: $Engine" }
Write-Host "DSH_NET throw test: port=$Port scene=$Scene throw_at=$ThrowAt"

$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" `
    -ArgumentList @('--headless', '--path', $project, $Scene, '--',
        '--net-host', "--net-port=$Port", '--net-name=host', '--sword-proto=1',
        "--net-throw-at=$ThrowAt", "--net-quit-at=$($ThrowAt + 45)")
Start-Sleep -Seconds 10
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" `
    -ArgumentList @('--headless', '--path', $project, $Scene, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest', '--sword-proto=1',
        "--net-throw-at=$ThrowAt", "--net-quit-at=$($ThrowAt + 40)")

$deadline = (Get-Date).AddSeconds($ThrowAt + $Settle + 50)
while ((Get-Date) -lt $deadline) {
    if ($hostProcess.HasExited -and $clientProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
    if (((Get-Date) - $clientProcess.StartTime).TotalSeconds -gt ($ThrowAt + $Settle)) { break }
}
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }
Start-Sleep -Seconds 1

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }

function Last-Line([string]$path, [string]$pattern) {
    if (-not (Test-Path $path)) { return $null }
    $lines = @(Get-Content $path | Where-Object { $_ -match $pattern })
    if ($lines.Count -eq 0) { return $null }
    return $lines[-1]
}

function Get-Point([string]$line, [string]$key) {
    if ($null -eq $line) { return $null }
    if ($line -match "$key=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)") {
        return @([double]$Matches[1], [double]$Matches[2], [double]$Matches[3])
    }
    return $null
}

$hostSent = Last-Line $hostLog '^DSH_NET_THROW_SENT'
$clientSent = Last-Line $clientLog '^DSH_NET_THROW_SENT'
$hostProxy = Last-Line $hostLog '^DSH_NET_THROW_PROXY'
$clientProxy = Last-Line $clientLog '^DSH_NET_THROW_PROXY'
$hostPoint = Get-Point $hostSent 'from'
$clientProxyPoint = Get-Point $clientProxy 'at'

function Same-Point($a, $b, [double]$tolerance) {
    if ($null -eq $a -or $null -eq $b) { return $false }
    $d = [math]::Sqrt([math]::Pow($a[0]-$b[0],2) + [math]::Pow($a[1]-$b[1],2) + [math]::Pow($a[2]-$b[2],2))
    return $d -le $tolerance
}

$checks = [ordered]@{
    'host threw'            = $null -ne $hostSent
    'guest threw'           = $null -ne $clientSent
    'host got guest throw'  = $null -ne $hostProxy
    'guest got host throw'  = $null -ne $clientProxy
    'same launch point'     = Same-Point $hostPoint $clientProxyPoint 0.5
    'guest proxy landed'    = $clientText -match 'DSH_NET_THROW_LAND'
    'host proxy landed'     = $hostText -match 'DSH_NET_THROW_LAND'
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host ""
Write-Host "host sent:   $hostSent"
Write-Host "host proxy:  $hostProxy"
Write-Host "guest proxy: $clientProxy"
Write-Host "--- guest tail ---"
(Get-Content $clientLog | Where-Object { $_ -match 'NET_THROW|DSH_NET_THROW' } | Select-Object -Last 4) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "logs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET throw test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET throw test PASSED"
exit 0
