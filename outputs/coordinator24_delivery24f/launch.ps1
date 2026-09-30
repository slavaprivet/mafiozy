$ErrorActionPreference = 'Stop'
$previewRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$previewRevision = 's01-20260930-quality24f'
$previewDir = Join-Path $PSScriptRoot 'play'
$previewPack = Join-Path $previewDir 'MafioziPreview.pck'
$previewExe = Join-Path $previewDir 'MafioziPreview.exe'
$previewPromotion = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'PROMOTION.json') -Raw | ConvertFrom-Json
if ($previewPromotion.status -ne 'APPLIED_NOT_LAUNCHED' -or $previewPromotion.revision -ne $previewRevision) { throw 'Expected applied 24f promotion receipt.' }
$previewNotes = Get-Content -LiteralPath (Join-Path $previewRepo 'godot\mafiozi_walk\data\preview_updates.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($previewNotes.runtime_revision -ne $previewRevision) { throw 'Shared revision is not 24f.' }
$previewGames = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' -and $_.CommandLine -match '--path|--main-pack|--script|MafioziPreview' -and $_.CommandLine -notmatch '--headless' })
if ($previewGames.Count -gt 0) { Write-Output 'A game is already open.'; exit 2 }
if ((Get-FileHash -LiteralPath $previewPack -Algorithm SHA256).Hash.ToLowerInvariant() -ne '0bd000e02db726dd9e7eccff565982222ce8dc0ef5b950209edf0c0f600d945e') { throw 'Verified 24f pack changed.' }
if ((Get-FileHash -LiteralPath $previewExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562') { throw 'Verified executable changed.' }
$previewProcess = Start-Process -FilePath $previewExe -WorkingDirectory $previewDir -WindowStyle Normal -PassThru -RedirectStandardOutput (Join-Path $PSScriptRoot 'play.log') -RedirectStandardError (Join-Path $PSScriptRoot 'play.err')
$previewProcess.Id | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'play.pid')
Write-Output $previewProcess.Id
$previewProcess.WaitForExit()
$previewExit = [ordered]@{ pid = $previewProcess.Id; revision = $previewRevision; exit_code = $previewProcess.ExitCode; exited_utc = [DateTime]::UtcNow.ToString('o') }
$previewExit | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'play.exit.json') -Encoding UTF8
