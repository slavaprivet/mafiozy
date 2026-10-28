# DSH_NET - отрицательный тест авторитета (по замечанию ревьюера).
#
# Сценарий "подделанный клиент": гость шлёт событие destruction напрямую, как это
# сделал бы модифицированный клиент, минуя castle.apply_explosion. Хост обязан
# отклонить событие (DSH_NET_REJECT_EVENT) и НЕ пересылать его другим.
# Затем тот же гость делает законный запрос (destruction_request) - он должен
# сработать, иначе тест проходил бы "просто потому, что всё сломано".
#
# Критерии:
#   * у хоста есть DSH_NET_REJECT_EVENT kind=destruction;
#   * взрывов ровно по одному на каждой стороне (подделка не добавила второй);
#   * мгновенный урон взрыва совпал у обеих сторон.

param(
    [int]$Port = 7897,
    [double]$InjectAt = 12.0,
    [double]$LegitAt = 22.0,
    [double]$Settle = 26.0,
    [string]$Engine = "$env:LOCALAPPDATA\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runs = Join-Path $PSScriptRoot 'runs'
New-Item -ItemType Directory -Force -Path $runs | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$hostLog = Join-Path $runs "auth_host_$stamp.log"
$clientLog = Join-Path $runs "auth_client_$stamp.log"

if (-not (Test-Path $Engine)) { throw "Godot not found: $Engine" }
Write-Host "DSH_NET authority test: port=$Port inject_at=$InjectAt legit_at=$LegitAt"

$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        '--net-host', "--net-port=$Port", '--net-name=host', '--net-castle-stats=6')
Start-Sleep -Seconds 12
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest', '--net-castle-stats=6',
        "--net-inject-at=$InjectAt", "--net-blast-at=$LegitAt")

$deadline = (Get-Date).AddSeconds($LegitAt + $Settle + 30)
while ((Get-Date) -lt $deadline) {
    if ($hostProcess.HasExited -and $clientProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
    if (((Get-Date) - $clientProcess.StartTime).TotalSeconds -gt ($LegitAt + $Settle)) { break }
}
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }
Start-Sleep -Seconds 1

function Get-ExplosionBricks([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    $counts = @()
    foreach ($line in (Get-Content $path | Where-Object { $_ -match 'NET_EXPLOSION ' })) {
        if ($line -match 'dead=(\d+)') { $counts += [int]$Matches[1] }
    }
    return $counts
}

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }
$hostBricks = @(Get-ExplosionBricks $hostLog)
$clientBricks = @(Get-ExplosionBricks $clientLog)
$hostSorted = ($hostBricks | Sort-Object) -join ','
$clientSorted = ($clientBricks | Sort-Object) -join ','
$hostApplied = ([regex]::Matches($hostText, 'NET_DESTRUCTION_APPLIED')).Count
$clientApplied = ([regex]::Matches($clientText, 'NET_DESTRUCTION_APPLIED')).Count

$checks = [ordered]@{
    'guest sent forged event'    = $clientText -match 'NET_INJECT kind=destruction'
    'host rejected forged event' = $hostText -match 'DSH_NET_REJECT_EVENT kind=destruction'
    'forged event not applied'   = ($hostBricks.Count -eq 1) -and ($clientBricks.Count -eq 1)
    'legit request still works'  = ($hostBricks.Count -eq 1) -and ($hostSorted -eq $clientSorted) -and ($hostApplied -ge 1)
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host ""
Write-Host "applied host=$hostApplied guest=$clientApplied; bricks per explosion host=[$hostSorted] guest=[$clientSorted]"
Write-Host "--- host ---"
(Get-Content $hostLog | Where-Object { $_ -match 'REJECT_EVENT|NET_INJECT|NET_EXPLOSION|NET_DESTRUCTION|NET_BLAST' } | Select-Object -Last 5) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "--- guest ---"
(Get-Content $clientLog | Where-Object { $_ -match 'NET_INJECT|NET_EXPLOSION|NET_DESTRUCTION|NET_BLAST' } | Select-Object -Last 5) | ForEach-Object { Write-Host $_.Trim() }
Write-Host ""
Write-Host "logs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET authority test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET authority test PASSED"
exit 0
