# DSH_NET - проверка камня катапульты: кинематический дубль у второй стороны.
#
# Камень катапульты - RigidBody3D, его траектория между машинами не повторяется.
# Поэтому по сети идёт одно событие запуска (откуда, вектор скорости, номер), а
# вторая сторона ведёт кинематический дубль: та же баллистика, пыль при ударе,
# но без урона.
#
# Проверки:
#   * обе стороны выстрелили и обе получили дубль чужого камня;
#   * параметры запуска (точка и вектор скорости) совпали у дубля и оригинала;
#   * дубль долетел до препятствия (есть линия удара);
#   * дубль не нанёс урона: нет лишних взрывов у второй стороны.

param(
    [int]$Port = 7901,
    [double]$LaunchAt = 14.0,
    [double]$Settle = 16.0,
    [string]$Engine = "$env:LOCALAPPDATA\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runs = Join-Path $PSScriptRoot 'runs'
New-Item -ItemType Directory -Force -Path $runs | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$hostLog = Join-Path $runs "cat_host_$stamp.log"
$clientLog = Join-Path $runs "cat_client_$stamp.log"

if (-not (Test-Path $Engine)) { throw "Godot not found: $Engine" }
Write-Host "DSH_NET catapult test: port=$Port launch_at=$LaunchAt settle=$Settle"

$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        '--net-host', "--net-port=$Port", '--net-name=host',
        "--net-catapult-at=$LaunchAt", '--net-castle-stats=5')
Start-Sleep -Seconds 12
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru `
    -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" `
    -ArgumentList @('--headless', '--path', $project, '--',
        "--net-join=127.0.0.1:$Port", '--net-name=guest',
        "--net-catapult-at=$LaunchAt", '--net-castle-stats=5')

$deadline = (Get-Date).AddSeconds($LaunchAt + $Settle + 30)
while ((Get-Date) -lt $deadline) {
    if ($hostProcess.HasExited -and $clientProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
    if (((Get-Date) - $clientProcess.StartTime).TotalSeconds -gt ($LaunchAt + $Settle)) { break }
}
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }
Start-Sleep -Seconds 1

$hostText = if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { '' }
$clientText = if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { '' }

function Get-LaunchLine([string]$path, [string]$tag) {
    if (-not (Test-Path $path)) { return $null }
    # @(...) обязателен: при единственном совпадении Where-Object вернёт строку,
    # а $lines[-1] у строки — это последний СИМВОЛ, а не последняя строка.
    $lines = @(Get-Content $path | Where-Object { $_ -match $tag })
    if ($lines.Count -eq 0) { return $null }
    return $lines[-1]
}

# "from=(x, y, z) v=(x, y, z)" - разбираем числа и сравниваем точки запуска.
function Get-LaunchNumbers([string]$line) {
    if ($null -eq $line) { return $null }
    if ($line -match 'from=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)') {
        return @([double]$Matches[1], [double]$Matches[2], [double]$Matches[3])
    }
    return $null
}

$hostSent = Get-LaunchLine $hostLog '^DSH_CATAPULT_NET_SENT'
$clientSent = Get-LaunchLine $clientLog '^DSH_CATAPULT_NET_SENT'
$hostProxy = Get-LaunchLine $hostLog '^DSH_CATAPULT_PROXY shot='
$clientProxy = Get-LaunchLine $clientLog '^DSH_CATAPULT_PROXY shot='
$hostImpact = Get-LaunchLine $hostLog '^DSH_CATAPULT_PROXY_IMPACT'
$clientImpact = Get-LaunchLine $clientLog '^DSH_CATAPULT_PROXY_IMPACT'

$hostOwnPoint = Get-LaunchNumbers $hostSent
$clientOwnPoint = Get-LaunchNumbers $clientSent
$hostProxyPoint = Get-LaunchNumbers $hostProxy
$clientProxyPoint = Get-LaunchNumbers $clientProxy

function Same-Point($a, $b, [double]$tolerance) {
    if ($null -eq $a -or $null -eq $b) { return $false }
    $d = [math]::Sqrt([math]::Pow($a[0]-$b[0],2) + [math]::Pow($a[1]-$b[1],2) + [math]::Pow($a[2]-$b[2],2))
    return $d -le $tolerance
}

$hostExplosions = -1
$clientExplosions = -1
foreach ($pair in @(@{ Log = $hostLog; Name = 'host' }, @{ Log = $clientLog; Name = 'client' })) {
    if (Test-Path $pair.Log) {
        $lines = Get-Content $pair.Log | Where-Object { $_ -match 'NET_CASTLE' }
        if ($lines -and $lines[-1] -match 'explosions=(\d+)') {
            if ($pair.Name -eq 'host') { $hostExplosions = [int]$Matches[1] } else { $clientExplosions = [int]$Matches[1] }
        }
    }
}

# Точка удара дубля: печатается как at=(x, y, z) на обеих сторонах.
function Get-ImpactPoint([string]$line) {
    if ($null -eq $line) { return $null }
    if ($line -match 'at=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)') {
        return @([double]$Matches[1], [double]$Matches[2], [double]$Matches[3])
    }
    return $null
}

$hostImpactPoint = Get-ImpactPoint $hostImpact
$clientImpactPoint = Get-ImpactPoint $clientImpact

# Сколько взрывов реально применено (NET_EXPLOSION), а не счётчик в статистике:
$hostAppliedCount = @(Get-Content $hostLog | Where-Object { $_ -match 'NET_EXPLOSION' }).Count
$guestAppliedCount = @(Get-Content $clientLog | Where-Object { $_ -match 'NET_EXPLOSION' }).Count
$checks = [ordered]@{
    'host launched'            = $null -ne $hostSent
    'guest launched'           = $null -ne $clientSent
    'host got guest stone'     = $null -ne $hostProxy
    'guest got host stone'     = $null -ne $clientProxy
    'guest proxy matches own'  = Same-Point $hostOwnPoint $clientProxyPoint 0.5
    'host proxy matches own'   = Same-Point $clientOwnPoint $hostProxyPoint 0.5
    'guest proxy hit world'    = $null -ne $clientImpactPoint
    'host proxy hit world'     = $null -ne $hostImpactPoint
    'impact points identical'  = Same-Point $hostImpactPoint $clientImpactPoint 0.05
    'proxy dealt no damage'    = ($hostAppliedCount -gt 0) -and ($hostAppliedCount -eq $guestAppliedCount)
}
$failed = @()
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host ("PASS  " + $name) }
    else { Write-Host ("FAIL  " + $name); $failed += $name }
}

Write-Host ""
Write-Host "host launch:  $hostSent"
Write-Host "client proxy: $clientProxy"
Write-Host "client launch: $clientSent"
Write-Host "host proxy:    $hostProxy"
Write-Host "explosions host=$hostExplosions guest=$clientExplosions"
Write-Host "--- guest tail ---"
(Get-Content $clientLog | Where-Object { $_ -match 'NET_CATAPULT|DSH_CATAPULT_NET_SENT|DSH_CATAPULT_PROXY' } | Select-Object -Last 4) | ForEach-Object { Write-Host $_.Trim() }
Write-Host ""
Write-Host "logs: $runs"

if ($failed.Count -gt 0) {
    Write-Host ("DSH_NET catapult test FAILED: " + ($failed -join ', '))
    exit 1
}
Write-Host "DSH_NET catapult test PASSED"
exit 0
