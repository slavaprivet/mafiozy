$ErrorActionPreference = 'Stop'
$previewRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$previewRevision = 's01-20260930-quality25a'
$previewDir = Join-Path $PSScriptRoot 'play'
$previewPromotionPath = Join-Path $PSScriptRoot 'PROMOTION.json'
$previewPromotion = Get-Content -LiteralPath $previewPromotionPath -Raw -Encoding UTF8 | ConvertFrom-Json
function Get-PreviewHash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
if ($previewPromotion.status -ne 'APPLIED_NOT_LAUNCHED' -or $previewPromotion.revision -ne $previewRevision) { throw 'Expected applied unified25a receipt.' }
if ((Get-PreviewHash $PSCommandPath) -ne $previewPromotion.launcher_sha256) { throw 'Verified launcher changed.' }
if ((Get-PreviewHash (Join-Path $PSScriptRoot 'PREPARATION.json')) -ne $previewPromotion.prepared_receipt_sha256) { throw 'Preparation changed.' }
if ((Get-PreviewHash (Join-Path $PSScriptRoot 'ROOT_ACCEPTANCE34.json')) -ne $previewPromotion.acceptance_sha256) { throw 'Root acceptance changed.' }
$previewNotes = Get-Content -LiteralPath (Join-Path $previewRepo 'godot/mafiozi_walk/data/preview_updates.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($previewNotes.runtime_revision -ne $previewRevision) { throw 'Shared revision is not25a.' }
foreach ($previewProperty in $previewPromotion.changes.PSObject.Properties) {
    $previewShared = Join-Path (Join-Path $previewRepo 'godot/mafiozi_walk') $previewProperty.Name
    if ((Get-PreviewHash $previewShared) -ne $previewProperty.Value.after) { throw "Shared accepted file changed: $($previewProperty.Name)" }
}
$previewExe = Join-Path $previewDir 'MafioziPreview.exe'
$previewPack = Join-Path $previewDir 'MafioziPreview.pck'
if ((Get-PreviewHash $previewPack) -ne $previewPromotion.pack_sha256 -or (Get-PreviewHash $previewExe) -ne $previewPromotion.exe_sha256) { throw 'Verified25a binary changed.' }
# A machine-local mutex closes the check/launch race between these shortcuts.
$previewMutex = [Threading.Mutex]::new($false, 'Local\MafioziUnifiedPreviewLaunch')
$previewHeld = $false
try {
    try { $previewHeld = $previewMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $previewHeld = $true }
    if (-not $previewHeld) { Write-Output 'A unified preview launcher is already active.'; exit 2 }
    $previewGames = @(Get-CimInstance Win32_Process | Where-Object {
        $previewPlainManager = $_.Name -match '^Godot' -and $_.CommandLine -match '^\s*("[^"]+"|[^\s]+)\s*(--project-manager)?\s*$'
        $_.Name -match 'Godot|Mafiozi' -and $_.CommandLine -notmatch '--headless' -and -not $previewPlainManager
    })
    if ($previewGames.Count -gt 0) { Write-Output 'A game or GPU engine is already open; it was preserved.'; exit 2 }
    $previewRun = Join-Path $PSScriptRoot ('ordinary/' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
    New-Item -ItemType Directory -Path $previewRun | Out-Null
    $previewLog = Join-Path $previewRun 'play.log'
    $previewErr = Join-Path $previewRun 'play.err'
    # This is the requested visible ordinary game, with no installer or QA script.
    $previewProcess = Start-Process -FilePath $previewExe -WorkingDirectory $previewDir -WindowStyle Normal -PassThru -RedirectStandardOutput $previewLog -RedirectStandardError $previewErr
    $previewProcess.Id | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'play.pid')
    $previewStarted = [ordered]@{ pid=$previewProcess.Id; revision=$previewRevision; opened_utc=[DateTime]::UtcNow.ToString('o'); pack_sha256=$previewPromotion.pack_sha256; ordinary_no_QA=$true; run_directory=$previewRun }
    $previewStarted | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $previewRun 'STARTED.json') -Encoding UTF8
    $previewReady = $false
    [string]$previewText = ''
    $previewMarkers = @('MAFIOZI_PREVIEW_READY buildings=8', 'RESIDENT_POPULATION_STATUS ready', 'REAR_LIGHTS_READY true', 'STREET_LAMPS_STATUS ready', 'DAY_NIGHT_READY')
    $previewUntil = [DateTime]::UtcNow.AddSeconds(25)
    $previewFound = @()
    while ([DateTime]::UtcNow -lt $previewUntil -and -not $previewProcess.HasExited) {
        $previewProcess.Refresh()
        if (Test-Path -LiteralPath $previewLog) {
            $previewText = [string](Get-Content -LiteralPath $previewLog -Raw -Encoding UTF8)
        } else { $previewText = '' }
        $previewFound = @($previewMarkers | Where-Object { $previewText.Contains($_) })
        $previewReady = $previewFound.Count -eq $previewMarkers.Count -and $previewProcess.Responding -and $previewProcess.MainWindowHandle -ne 0
        if ($previewReady) { break }
        Start-Sleep -Milliseconds 250
    }
    [string]$previewErrorText = ''
    if (Test-Path -LiteralPath $previewErr) {
        $previewErrorText = [string](Get-Content -LiteralPath $previewErr -Raw -Encoding UTF8)
    }
    $previewRuntimeError = ($previewErrorText -match 'ERROR|Exception') -or ($previewText -match 'SCRIPT ERROR|ERROR:|Parse Error')
    $previewOpened = [ordered]@{ pid=$previewProcess.Id; revision=$previewRevision; opened_utc=$previewStarted.opened_utc; ready=($previewReady -and -not $previewRuntimeError); markers=$previewFound; responding=(!$previewProcess.HasExited -and $previewProcess.Responding); window_handle=$previewProcess.MainWindowHandle; error_log_empty=[string]::IsNullOrWhiteSpace($previewErrorText); runtime_error=[bool]$previewRuntimeError; pack_sha256=$previewPromotion.pack_sha256; ordinary_no_QA=$true; run_directory=$previewRun; dashboard_proof='Pinned native/packed/GPU acceptance; ordinary dashboard has no dedicated readiness log marker.' }
    $previewOpened | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $previewRun 'OPENED.json') -Encoding UTF8
    $previewOpened | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'OPENED.json') -Encoding UTF8
    Write-Output ($previewOpened | ConvertTo-Json -Depth 4 -Compress)
    $previewLaunchFailed = -not $previewOpened.ready
    if ($previewLaunchFailed) { Write-Warning 'Ordinary25a readiness failed; OPENED.json records the failure. The game is preserved; launcher will return nonzero when it exits.' }
    $previewProcess.WaitForExit()
    $previewExit = [ordered]@{ pid=$previewProcess.Id; revision=$previewRevision; exit_code=$previewProcess.ExitCode; launch_readiness_failed=$previewLaunchFailed; launcher_exit_code=$(if ($previewLaunchFailed -or $previewProcess.ExitCode -ne 0) { 1 } else { 0 }); exited_utc=[DateTime]::UtcNow.ToString('o'); run_directory=$previewRun }
    $previewExit | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $previewRun 'EXIT.json') -Encoding UTF8
    $previewExit | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'play.exit.json') -Encoding UTF8
    if ($previewLaunchFailed -or $previewProcess.ExitCode -ne 0) { exit 1 }
} finally {
    if ($previewHeld) { $previewMutex.ReleaseMutex() }
    $previewMutex.Dispose()
}
