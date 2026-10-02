param([int]$FromGodotPid = 0, [switch]$CheckOnly, [switch]$Quiet)
$ErrorActionPreference = 'Stop'
$currentRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$currentPointerPath = Join-Path $currentRepo 'godot/current_version.json'
$currentMutex = $null
$currentHeld = $false
function Show-CurrentMessage([string]$Message) {
    Write-Output $Message
    if (-not $Quiet -and -not $CheckOnly) {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show($Message, 'Мафиози — актуальная версия', 'OK', 'Information') | Out-Null
    }
}
function Resolve-CurrentFile([string]$Relative) {
    $resolved = [IO.Path]::GetFullPath((Join-Path $currentRepo $Relative))
    if (-not $resolved.StartsWith($currentRepo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Release path leaves the project.' }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Release file missing: $Relative" }
    return $resolved
}
function Assert-CurrentHash([string]$Path, [string]$Expected) {
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Expected) { throw "Verified release changed: $Path" }
}
function Assert-CurrentF5Route {
    $currentProject = Resolve-CurrentFile 'godot/mafiozi_walk/project.godot'
    $currentForwardScene = Resolve-CurrentFile 'godot/mafiozi_walk/scenes/current_version_launcher.tscn'
    $currentForwardScript = Resolve-CurrentFile 'godot/mafiozi_walk/scripts/current_version_launcher.gd'
    if ((Get-Content -LiteralPath $currentProject -Raw -Encoding UTF8) -notmatch '(?m)^run/main_scene="res://scenes/current_version_launcher\.tscn"\s*$') { throw 'F5 no longer points to the current-version launcher.' }
    if ((Get-Content -LiteralPath $currentForwardScene -Raw -Encoding UTF8) -notmatch 'path="res://scripts/current_version_launcher\.gd"') { throw 'F5 forwarding scene is disconnected.' }
    if ((Get-Content -LiteralPath $currentForwardScript -Raw -Encoding UTF8) -notmatch 'tools/godot/launch_current_game\.ps1') { throw 'F5 no longer resolves the shared current-version pointer.' }
    return $currentProject
}
try {
    # F5's small forwarding scene exits before the real game is created.
    if ($FromGodotPid -gt 0) {
        $currentForwarder = Get-Process -Id $FromGodotPid -ErrorAction SilentlyContinue
        if ($currentForwarder -and $currentForwarder.ProcessName -notmatch '^Godot') { throw 'Unexpected F5 forwarding process.' }
        $currentWaitUntil = [DateTime]::UtcNow.AddSeconds(15)
        while ((Get-Process -Id $FromGodotPid -ErrorAction SilentlyContinue) -and [DateTime]::UtcNow -lt $currentWaitUntil) { Start-Sleep -Milliseconds 100 }
        if (Get-Process -Id $FromGodotPid -ErrorAction SilentlyContinue) { throw 'F5 forwarding scene has not exited; nothing else was started.' }
    }
    $currentRelease = Get-Content -LiteralPath $currentPointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($currentRelease.schema -ne 'mafiozi.current-play/v1') { throw 'Unknown current release format.' }
    $currentManifestPath = Resolve-CurrentFile $currentRelease.assembly
    Assert-CurrentHash $currentManifestPath $currentRelease.assembly_sha256
    $currentManifest = Get-Content -LiteralPath $currentManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($currentManifest.revision -ne $currentRelease.revision) { throw 'Current release revision mismatch.' }
    $currentGameDir = [IO.Path]::GetFullPath($currentManifest.game)
    if (-not $currentGameDir.StartsWith($currentRepo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected game directory.' }
    $currentBootstrap = Resolve-CurrentFile $currentRelease.bootstrap
    Assert-CurrentHash $currentBootstrap $currentRelease.bootstrap_sha256
    $currentEngine = Join-Path $env:LOCALAPPDATA 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    Assert-CurrentHash $currentEngine $currentRelease.engine_sha256
    if ($CheckOnly) {
        $currentF5Project = Assert-CurrentF5Route
        foreach ($currentPin in $currentManifest.source_pins.PSObject.Properties) { Assert-CurrentHash (Join-Path $currentGameDir $currentPin.Name) $currentPin.Value }
        Write-Output ('CURRENT_READY ' + $currentRelease.revision + ' / ' + $currentRelease.title)
        Write-Output ('F5_READY ' + $currentF5Project)
        exit 0
    }
    $currentMutex = [Threading.Mutex]::new($false, 'Local\MafioziUnifiedPreviewLaunch')
    try { $currentHeld = $currentMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $currentHeld = $true }
    if (-not $currentHeld) { Show-CurrentMessage 'Игра уже открыта или сейчас идёт проверка обновления. Второе окно не запущено.'; exit 2 }
    $currentInventory = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|MafioziPreview' })
    foreach ($currentEntry in $currentInventory) {
        $currentWindow = Get-Process -Id $currentEntry.ProcessId -ErrorAction SilentlyContinue
        $currentPlainManager = $currentEntry.Name -match '^Godot_v4\.(6\.3|7\.2)-stable_win64(_console)?\.exe$' -and $currentEntry.CommandLine -match '^\s*("[^"]+"|[^\s]+)\s*(--project-manager)?\s*$' -and $currentWindow.MainWindowTitle -match '^Godot Engine - (Менеджер проектов|Project Manager)$'
        $currentEditor = $currentEntry.Name -match '^Godot' -and $currentEntry.CommandLine -match '(?i)(?:^|\s)(?:--editor|-e)(?:\s|$)' -and $currentEntry.CommandLine -notmatch '(?i)--headless|--script|--import|--export'
        if (-not $currentPlainManager -and -not $currentEditor) { Show-CurrentMessage 'Другая игра или проверка ещё работает. Закройте игровое окно и снова запустите «Мафиози — актуальная версия». Текущая игра сохранена.'; exit 2 }
    }
    foreach ($currentPin in $currentManifest.source_pins.PSObject.Properties) { Assert-CurrentHash (Join-Path $currentGameDir $currentPin.Name) $currentPin.Value }
    $currentRun = Join-Path $currentRepo ('outputs/current_game/interactive/' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
    New-Item -ItemType Directory -Path $currentRun -Force | Out-Null
    Copy-Item -LiteralPath $currentPointerPath -Destination (Join-Path $currentRun 'RELEASE.json')
    $currentLog = Join-Path $currentRun 'play.log'
    $currentErr = Join-Path $currentRun 'play.err'
    $currentArgs = @('--path', ('"' + $currentGameDir + '"'), '--script', ('"' + $currentBootstrap + '"'), '--', ('"--receipt-dir=' + $currentRun + '"'), ('"--release-title=' + $currentRelease.title + '"'), ('"--release-revision=' + $currentRelease.revision + '"'))
    # A visible game is the explicit purpose of this user launcher.
    $currentProcess = Start-Process -FilePath $currentEngine -ArgumentList $currentArgs -WorkingDirectory $currentGameDir -WindowStyle Normal -PassThru -RedirectStandardOutput $currentLog -RedirectStandardError $currentErr
    $currentReceipt = [ordered]@{ pid=$currentProcess.Id; revision=$currentRelease.revision; title=$currentRelease.title; source='stable_user_launcher'; run_directory=$currentRun; started_at=$currentProcess.StartTime.ToString('o'); assembly_sha256=$currentRelease.assembly_sha256 }
    $currentReceipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $currentRun 'STARTED.json') -Encoding UTF8
    $currentReadyUntil = [DateTime]::UtcNow.AddSeconds(40)
    $currentReadyPath = Join-Path $currentRun 'CURRENT_READY.json'
    while ([DateTime]::UtcNow -lt $currentReadyUntil) {
        $currentProcess.Refresh()
        if ($currentProcess.HasExited -or (Test-Path -LiteralPath $currentReadyPath)) { break }
        Start-Sleep -Milliseconds 200
    }
    $currentProcess.Refresh()
    $currentReady = if (Test-Path -LiteralPath $currentReadyPath) { Get-Content -LiteralPath $currentReadyPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
    [string]$currentErrorText = if (Test-Path -LiteralPath $currentErr) { Get-Content -LiteralPath $currentErr -Raw -Encoding UTF8 } else { '' }
    $currentReceipt.ready = ($null -ne $currentReady -and $currentReady.ok -eq $true -and [string]$currentReady.revision -ceq [string]$currentRelease.revision -and -not $currentProcess.HasExited -and $currentProcess.Responding -and [string]::IsNullOrWhiteSpace($currentErrorText))
    $currentReceipt.window_handle = if ($currentProcess.HasExited) { 0 } else { $currentProcess.MainWindowHandle.ToInt64() }
    $currentReceipt.bootstrap = $currentReady
    $currentReceipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $currentRun 'OPENED.json') -Encoding UTF8
    $currentReceipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $currentRepo 'outputs/current_game/OPENED.json') -Encoding UTF8
    Write-Output ($currentReceipt | ConvertTo-Json -Depth 5 -Compress)
    if (-not $currentReceipt.ready) { Show-CurrentMessage 'Игра не подтвердила готовность. Окно и журнал сохранены; старую версию автоматически не запускаю.' }
    if (-not $currentProcess.HasExited) { $currentProcess.WaitForExit() }
    if (-not $currentReceipt.ready) { exit 1 }
} catch {
    Show-CurrentMessage ('Не удалось открыть актуальную версию: ' + $_.Exception.Message)
    exit 1
} finally {
    if ($currentHeld) { $currentMutex.ReleaseMutex() }
    if ($null -ne $currentMutex) { $currentMutex.Dispose() }
}
