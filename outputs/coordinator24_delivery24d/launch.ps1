$ErrorActionPreference = 'Stop'
$previewRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$previewDir = Join-Path $previewRepo 'godot\mafiozi_walk\exports\win64\s01-20260930-quality24d-play'
$previewPack = Join-Path $previewDir 'MafioziPreview.pck'
$previewExe = Join-Path $previewDir 'MafioziPreview.exe'
$previewGames = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' -and $_.CommandLine -match '--path|--main-pack|--script|MafioziPreview' -and $_.CommandLine -notmatch '--headless' })
if ($previewGames.Count -gt 0) { Write-Output 'Игра уже открыта.'; exit 2 }
if ((Get-FileHash -LiteralPath $previewPack -Algorithm SHA256).Hash.ToLower() -ne '21c0c2799589fe19b3c506fe8b3d0fc304f4a3f1701ec43013e8c9a3c506e63f') { throw 'Изменена проверенная сборка игры.' }
$previewProcess = Start-Process -FilePath $previewExe -WorkingDirectory $previewDir -PassThru -RedirectStandardOutput (Join-Path $PSScriptRoot 'play.log') -RedirectStandardError (Join-Path $PSScriptRoot 'play.err')
$previewProcess.Id | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'play.pid')
