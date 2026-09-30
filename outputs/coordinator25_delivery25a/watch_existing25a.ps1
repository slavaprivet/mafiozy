$ErrorActionPreference = 'Stop'
$previewProcess = Get-Process -Id 53140
$previewExpected = Join-Path $PSScriptRoot 'play/MafioziPreview.exe'
if ($previewProcess.Path -ne $previewExpected -or $previewProcess.StartTime.ToUniversalTime().ToString('yyyyMMddTHHmmss') -ne '20260930T192226') { throw 'Ordinary process identity changed; no action taken.' }
$previewRun = Join-Path $PSScriptRoot 'ordinary/20260930T192225602Z'
$previewStarted = Get-Content -LiteralPath (Join-Path $previewRun 'STARTED.json') -Raw | ConvertFrom-Json
$previewPromotion = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'PROMOTION.json') -Raw | ConvertFrom-Json
$previewPackHash = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'play/MafioziPreview.pck') -Algorithm SHA256).Hash.ToLowerInvariant()
if ($previewPackHash -ne $previewStarted.pack_sha256 -or $previewPackHash -ne $previewPromotion.pack_sha256) { throw 'Pack pin differs.' }
[string]$previewText = Get-Content -LiteralPath (Join-Path $previewRun 'play.log') -Raw -Encoding utf8
[string]$previewErrors = Get-Content -LiteralPath (Join-Path $previewRun 'play.err') -Raw -Encoding utf8
$previewMarkers = @('MAFIOZI_PREVIEW_READY buildings=8','RESIDENT_POPULATION_STATUS ready','REAR_LIGHTS_READY true','STREET_LAMPS_STATUS ready','DAY_NIGHT_READY')
$previewFound = @($previewMarkers | Where-Object { $previewText.Contains($_) })
$previewProcess.Refresh()
$previewReady = $previewFound.Count -eq $previewMarkers.Count -and $previewProcess.Responding -and $previewProcess.MainWindowHandle -ne 0 -and $previewErrors -notmatch 'ERROR|Exception' -and $previewText -notmatch 'SCRIPT ERROR|ERROR:|Parse Error'
$previewOpened = [ordered]@{ pid=53140; revision='s01-20260930-quality25a'; opened_utc=$previewStarted.opened_utc; verified_utc=[DateTime]::UtcNow.ToString('o'); ready=$previewReady; markers=$previewFound; responding=$previewProcess.Responding; window_handle=$previewProcess.MainWindowHandle; error_log_empty=[string]::IsNullOrWhiteSpace($previewErrors); pack_sha256=$previewPackHash; ordinary_no_QA=$true; run_directory=$previewRun; original_wrapper_error='Empty initial log produced null before game became ready; repaired launcher. This observer attaches to the same preserved process.'; visual_limit='Ordinary native capture timed out; actual exact-PCK GPU fixture screenshots separately reviewed.' }
$previewOpened | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $previewRun 'OPENED.json') -Encoding utf8
$previewOpened | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'OPENED.json') -Encoding utf8
Write-Output ($previewOpened | ConvertTo-Json -Depth 4 -Compress)
$previewProcess.WaitForExit()
$previewExit = [ordered]@{pid=53140;revision='s01-20260930-quality25a';exit_code=$previewProcess.ExitCode;exited_utc=[DateTime]::UtcNow.ToString('o');observer=$true}
$previewExit | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $previewRun 'EXIT.json') -Encoding utf8
$previewExit | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'play.exit.json') -Encoding utf8
if (-not $previewReady) { exit 1 }
