param(
    [int]$Port = 7911,
    [double]$MoveAt = 12.0,
    [double]$Settle = 26.0,
    [string]$Engine = "$env:LOCALAPPDATA\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runs = Join-Path $PSScriptRoot 'runs'
New-Item -ItemType Directory -Force -Path $runs | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$hostLog = Join-Path $runs "ship_host_$stamp.log"
$clientLog = Join-Path $runs "ship_client_$stamp.log"
$hostProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" -ArgumentList @('--headless','--path',$project,'--','--net-host',"--net-port=$Port",'--net-name=host',"--net-ship-at=$MoveAt",'--net-ship-stats=4',"--net-quit-at=$($MoveAt + 40)")
Start-Sleep -Seconds 12
$clientProcess = Start-Process -FilePath $Engine -NoNewWindow -PassThru -RedirectStandardOutput $clientLog -RedirectStandardError "$clientLog.err" -ArgumentList @('--headless','--path',$project,'--',"--net-join=127.0.0.1:$Port",'--net-name=guest','--net-ship-stats=4',"--net-quit-at=$($MoveAt + 36)")
$deadline = (Get-Date).AddSeconds($MoveAt + $Settle + 40)
while ((Get-Date) -lt $deadline) { if ($hostProcess.HasExited -and $clientProcess.HasExited) { break }; Start-Sleep -Milliseconds 500 }
if (-not $hostProcess.HasExited) { $hostProcess.Kill() }
if (-not $clientProcess.HasExited) { $clientProcess.Kill() }
Start-Sleep -Seconds 1

$hostPos = @(); $clientState = @(); $hostStart = $null
foreach ($l in (Get-Content $hostLog | Where-Object { $_ -match '^NET_SHIP' })) {
    if ($l -match 'pos=\(([-\d]+),([-\d.]+),([-\d.]+)\)' -and $l -match 'NET_SHIP start') { $hostStart = @([double]$Matches[1],[double]$Matches[2],[double]$Matches[3]) }
}
$startLine = @(Get-Content $hostLog | Where-Object { $_ -match '^NET_SHIP start' })
if ($startLine.Count -gt 0 -and $startLine[-1] -match 'pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)') { $hostStart = @([double]$Matches[1],[double]$Matches[2],[double]$Matches[3]) }
foreach ($l in (Get-Content $hostLog | Where-Object { $_ -match '^NET_SHIP t=' })) {
    if ($l -match 'pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)') { $hostPos += ,@([double]$Matches[1],[double]$Matches[2],[double]$Matches[3]) }
}
foreach ($l in (Get-Content $clientLog | Where-Object { $_ -match '^NET_SHIP t=' })) {
    if ($l -match 'state_pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)') { $clientState += ,@([double]$Matches[1],[double]$Matches[2],[double]$Matches[3]) }
}

$hostMoved = -1.0
if ($hostPos.Count -ge 2) {
    $a = $hostPos[0]; $b = $hostPos[$hostPos.Count-1]
    $hostMoved = [math]::Sqrt([math]::Pow($b[0]-$a[0],2)+[math]::Pow($b[1]-$a[1],2)+[math]::Pow($b[2]-$a[2],2))
}
$stateSpan = -1.0
if ($clientState.Count -ge 2) {
    $a = $clientState[0]; $b = $clientState[$clientState.Count-1]
    $stateSpan = [math]::Sqrt([math]::Pow($b[0]-$a[0],2)+[math]::Pow($b[1]-$a[1],2)+[math]::Pow($b[2]-$a[2],2))
}
$startGap = -1.0
if ($null -ne $hostStart -and $clientState.Count -gt 0) {
    $c = $clientState[0]
    $startGap = [math]::Sqrt([math]::Pow($c[0]-$hostStart[0],2)+[math]::Pow($c[1]-$hostStart[1],2)+[math]::Pow($c[2]-$hostStart[2],2))
}

$checks = [ordered]@{
    'host opened sails'    = ((Get-Content $hostLog -Raw) -match 'NET_SHIP start')
    'ship actually moved'  = ($hostMoved -gt 10.0)
    'guest got states'     = ($clientState.Count -ge 3)
    'received track live'  = ($stateSpan -gt 10.0)
    'track starts at ship' = ($startGap -ge 0.0) -and ($startGap -le 25.0)
}
$failed = @()
foreach ($name in $checks.Keys) { if ($checks[$name]) { Write-Host ("PASS  " + $name) } else { Write-Host ("FAIL  " + $name); $failed += $name } }
Write-Host ""
Write-Host "host moved=$([math]::Round($hostMoved,2)) m; received span=$([math]::Round($stateSpan,2)) m; start gap=$([math]::Round($startGap,2)) m"
Write-Host "logs: $runs"
if ($failed.Count -gt 0) { Write-Host ("DSH_NET ship test FAILED: " + ($failed -join ', ')); exit 1 }
Write-Host "DSH_NET ship test PASSED"; exit 0