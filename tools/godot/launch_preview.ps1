param(
    [string]$GodotExe = (Join-Path $env:LOCALAPPDATA 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe')
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot 'godot/mafiozi_walk')).Path
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
    throw 'Godot 4.7.2 не найден. Передайте путь параметром -GodotExe.'
}
$existingPreview = Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -eq $GodotExe -and $_.CommandLine -and $_.CommandLine.Contains($projectRoot)
}
if ($existingPreview) {
    Write-Output 'Сцена уже открыта. Дополнительный экземпляр не запущен.'
    $existingPreview | Select-Object ProcessId, Name
    return
}
Start-Process -FilePath $GodotExe -ArgumentList @('--path', ('"' + $projectRoot + '"')) -WindowStyle Normal
