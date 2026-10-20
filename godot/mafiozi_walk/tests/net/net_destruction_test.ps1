# DSH_NET - проверка этапа 3: авторитетное разрушение замка по сети.
#
# Хост и гость поднимают настоящий замок. Гость по таймеру просит хост взорвать
# участок стены, затем - створку ворот. Хост применяет удары у себя и рассылает
# результат: точный список кирпичей (dead) и состояние створок (gate).
#
# Проверки:
#   * запросы обработал именно хост;
#   * мгновенный урон каждого взрыва совпал у обеих сторон (сравнивается
#     `dead=` из NET_EXPLOSION, а не накопленный detached: каскад опор идёт во
#     времени, и процессы останавливаются в разные моменты);
#   * доски створок ворот разбиты и их число совпадает.

param(
    [int]$Port = 7871,
    [double]$BlastAt = 16.0,
    [double]$GateAt = 20.0,
    [double]$Settle = 30.0,
    [string]$Engine = "$env:LOCALAPPDATA\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runs = Join-Path $PSScriptRoot 'runs'
New-Item -ItemType Directory -Force -Path $runs | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$hostLog = Join-Path $runs "destr_host_$stamp.log"
$clientLog = Join-Path $runs "destr_client_$stamp.log"

if (-not (Test-Path $Engine)) { throw "Godot not found: $Engine" }
Write-Host "DSH_NET destruction test: port=$Port blast_at=$BlastAt gate_at=$GateAt settle=$Settle"

$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        '--net-host', "--net-port=$Port", '--net-name=host', '--net-castle-stats=3')
Start-Sleep -Seconds 12
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest', '--net-castle-stats=3',
        "--net-blast-at=$BlastAt", "--net-gate-at=$GateAt")

$deadline = (Get-Date).AddSeconds($GateAt + $Settle + 30)
while ((Get-Date) -lt $deadline) {
    if ($hostProcess.HasExited -and $clientProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
    if (((Get-Date) - $clientProcess.StartTime).TotalSeconds -gt ($GateAt + $Settle)) { break }
}
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }
Start-Sleep -Seconds 1

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }

function Get-ExplosionBricks([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    $counts = @()
    foreach ($line in (Get-Content $path | Where-Object { $_ -match 'NET_EXPLOSION ' })) {
        if ($line -match 'dead=(\d+)') { $counts += [int]$Matches[1] }
    }
    return $counts
}

function Get-LastStat([string]$path, [string]$name) {
    if (-not (Test-Path $path)) { return -1 }
    $lines = Get-Content $path | Where-Object { $_ -match 'NET_CASTLE' }
    if (-not $lines) { return -1 }
    if ($lines[-1] -match "$name=(-?\d+)") { return [int]$Matches[1] }
    return -1
}

$hostBricks = @(Get-ExplosionBricks $hostLog)
$clientBricks = @(Get-ExplosionBricks $clientLog)
$hostSorted = ($hostBricks | Sort-Object) -join ','
$clientSorted = ($clientBricks | Sort-Object) -join ','
$hostGates = Get-LastStat $hostLog 'gates'
$clientGates = Get-LastStat $clientLog 'gates'
$hostDetached = Get-LastStat $hostLog 'detached'

$checks = [ordered]@{
    'host built castle'          = $hostText -match 'DSH_SCENE_LOADED.*castle_map=true'
    'guest built castle'         = $clientText -match 'DSH_SCENE_LOADED.*castle_map=true'
    'guest asked host (wall)'    = $clientText -match 'NET_BLAST request'
    'guest asked host (gate)'    = $clientText -match 'NET_GATE request'
    'host applied blasts'        = ([regex]::Matches($hostText, 'NET_DESTRUCTION_APPLIED')).Count -ge 2
    'guest applied host blasts'  = ([regex]::Matches($clientText, 'NET_DESTRUCTION_APPLIED')).Count -ge 2
    'host broke masonry'         = ($hostDetached -gt 0)
    'two explosions per side'    = ($hostBricks.Count -eq 2) -and ($clientBricks.Count -eq 2)
    'same bricks on both sides'  = ($hostBricks.Count -gt 0) -and ($hostSorted -eq $clientSorted)
    'gate boards broke'          = ($hostGates -gt 0)
    'gate state replicated'      = ($hostGates -eq $clientGates)
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host ""
Write-Host "bricks per explosion: host=[$hostSorted] guest=[$clientSorted]"
Write-Host "gate boards: host=$hostGates guest=$clientGates; detached at stop host=$hostDetached"
Write-Host "--- host tail ---"
(Get-Content $hostLog | Where-Object { $_ -match 'NET_BLAST|NET_GATE|NET_EXPLOSION|NET_DESTRUCTION|NET_CASTLE' } | Select-Object -Last 5) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "--- guest tail ---"
(Get-Content $clientLog | Where-Object { $_ -match 'NET_BLAST|NET_GATE|NET_EXPLOSION|NET_DESTRUCTION|NET_CASTLE|NET_GATE_APPLIED' } | Select-Object -Last 5) | ForEach-Object { Write-Host $_.Trim() }
Write-Host ""
Write-Host "logs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET destruction test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET destruction test PASSED"
exit 0
