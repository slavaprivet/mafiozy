# DSH_NET — отрицательный тест авторитета (запрос ревьюера).
#
# Сценарий «подделанный клиент»: гость шлёт событие `destruction` напрямую, как
# это сделал бы модифицированный клиент, минуя castle.apply_explosion. Хост
# обязан отклонить событие (DSH_NET_REJECT_EVENT) и НЕ пересылать его другим.
# Затем тот же гость делает законный запрос (`destruction_request`) — он должен
# сработать, чтобы тест не проходил «просто потому, что всё сломано».
#
# Критерии:
#   * у хоста есть DSH_NET_REJECT_EVENT kind=destruction;
#   * применение взрыва ровно одно на каждой стороне (NET_DESTRUCTION_APPLIED),
#     то есть подделка не создала второе;
#   * итоговые счётчики выбитой кладки у хоста и гостя совпадают и больше нуля.
#
#   pwsh -File tests/net/net_authority_test.ps1

param(
    [int]$Port = 7897,
    [double]$InjectAt = 8.0,
    [double]$LegitAt = 16.0,
    [double]$Settle = 30.0,
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

function Get-LastDetached([string]$path) {
    if (-not (Test-Path $path)) { return -1 }
    $lines = Get-Content $path | Where-Object { $_ -match 'NET_CASTLE' }
    if (-not $lines) { return -1 }
    if ($lines[-1] -match 'detached=(\d+)') { return [int]$Matches[1] }
    return -1
}

function Count-Matches([string]$text, [string]$pattern) {
    return ([regex]::Matches($text, $pattern)).Count
}

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }
$hostDetached = Get-LastDetached $hostLog
$clientDetached = Get-LastDetached $clientLog
$hostApplied = Count-Matches $hostText 'NET_DESTRUCTION_APPLIED'
$clientApplied = Count-Matches $clientText 'NET_DESTRUCTION_APPLIED'

# Мгновенный урон каждого взрыва: `detached` в статистике ещё растёт от каскада
# опор, поэтому сравнивать его в конце прогона нельзя.
function Get-ExplosionKills([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    $kills = @()
    foreach ($line in (Get-Content $path | Where-Object { $_ -match 'NET_EXPLOSION ' })) {
        if ($line -match 'killed=(\d+)') { $kills += [int]$Matches[1] }
    }
    return $kills
}

$hostKills = @(Get-ExplosionKills $hostLog)
$clientKills = @(Get-ExplosionKills $clientLog)
$hostKillsSorted = ($hostKills | Sort-Object) -join ','
$clientKillsSorted = ($clientKills | Sort-Object) -join ','

$checks = [ordered]@{
    'guest sent forged event'   = $clientText -match 'NET_INJECT kind=destruction'
    'host rejected forged event'= $hostText -match 'DSH_NET_REJECT_EVENT kind=destruction'
    'forged event not applied'  = ($hostApplied -eq 1) -and ($clientApplied -eq 1) -and ($hostKills.Count -eq 1) -and ($clientKills.Count -eq 1)
    'legit request still works' = ($hostKills.Count -eq 1) -and ($hostKillsSorted -eq $clientKillsSorted) -and ($hostDetached -gt 0)
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host "`nhost applied=$hostApplied detached=$hostDetached  guest applied=$clientApplied detached=$clientDetached"
Write-Host "instant kills host=[$hostKillsSorted] guest=[$clientKillsSorted]"
Write-Host "--- host ---"
(Get-Content $hostLog | Where-Object { $_ -match 'REJECT_EVENT|NET_INJECT|NET_DESTRUCTION|NET_BLAST' } | Select-Object -Last 6) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "--- guest ---"
(Get-Content $clientLog | Where-Object { $_ -match 'NET_INJECT|NET_DESTRUCTION|NET_BLAST|NET_CASTLE' } | Select-Object -Last 6) | ForEach-Object { Write-Host $_.Trim() }
Write-Host "`nlogs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET authority test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET authority test PASSED"
exit 0
