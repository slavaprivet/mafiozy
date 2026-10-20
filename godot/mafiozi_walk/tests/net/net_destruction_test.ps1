# DSH_NET — проверка этапа 3: авторитетное разрушение замка по сети.
#
# Хост и гость поднимают настоящий замок. Гость по таймеру просит хост взорвать
# участок стены; хост применяет удар у себя и рассылает его. Оба процесса печатают
# счётчик выбитой кладки (detached). Проверка: у гостя кладка выбита ровно так же,
# как у хоста, и запрос действительно обработан хостом.
#
# Пример:
#   pwsh -File tests/net/net_destruction_test.ps1
#   pwsh -File tests/net/net_destruction_test.ps1 -Port 7877 -BlastAt 20 -Settle 40

param(
    [int]$Port = 7871,
    [double]$BlastAt = 18.0,
    [double]$Settle = 40.0,
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
Write-Host "DSH_NET destruction test: port=$Port blast_at=$BlastAt settle=$Settle"

$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        '--net-host', "--net-port=$Port", '--net-name=host', '--net-castle-stats=3')
Start-Sleep -Seconds 12
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest', '--net-castle-stats=3',
        "--net-blast-at=$BlastAt")

$deadline = (Get-Date).AddSeconds($BlastAt + $Settle + 30)
while ((Get-Date) -lt $deadline) {
    if ($hostProcess.HasExited -and $clientProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
    $clientElapsed = ((Get-Date) - $clientProcess.StartTime).TotalSeconds
    if ($clientElapsed -gt ($BlastAt + $Settle)) { break }
}
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }
Start-Sleep -Seconds 1

function Get-LastDetached([string]$path) {
    if (-not (Test-Path $path)) { return -1 }
    $lines = Get-Content $path | Where-Object { $_ -match 'NET_CASTLE' }
    if (-not $lines) { return -1 }
    $last = $lines[-1]
    if ($last -match 'detached=(\d+)') { return [int]$Matches[1] }
    return -1
}

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }
$hostDetached = Get-LastDetached $hostLog
$clientDetached = Get-LastDetached $clientLog

$checks = [ordered]@{
    'host built castle'        = $hostText -match 'DSH_SCENE_LOADED.*castle_map=true'
    'guest built castle'       = $clientText -match 'DSH_SCENE_LOADED.*castle_map=true'
    'guest asked host'         = $clientText -match 'NET_BLAST request'
    'host applied blast'       = $hostText -match 'NET_DESTRUCTION_APPLIED'
    'host broke masonry'       = ($hostDetached -gt 0)
    'guest applied host blast' = $clientText -match 'NET_DESTRUCTION_APPLIED'
    'guest broke same masonry' = ($clientDetached -eq $hostDetached) -and ($clientDetached -gt 0)
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host "`nhost detached=$hostDetached guest detached=$clientDetached"
Write-Host "--- host tail ---"
(Get-Content $hostLog | Where-Object { $_ -match 'NET_BLAST|NET_CASTLE|NET_DESTRUCTION|PEER_JOINED' } | Select-Object -Last 6) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "--- guest tail ---"
(Get-Content $clientLog | Where-Object { $_ -match 'NET_BLAST|NET_CASTLE|NET_DESTRUCTION|WELCOME' } | Select-Object -Last 6) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "`nlogs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET destruction test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET destruction test PASSED"
exit 0
