param(
    [string]$GodotExe = (Join-Path $env:LOCALAPPDATA 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'),
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot 'godot/mafiozi_walk')).Path
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
    throw 'Godot 4.7.2 не найден. Передайте путь параметром -GodotExe.'
}
$exportRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'exports/win64')) + [IO.Path]::DirectorySeparatorChar
$engineDirectory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($GodotExe))
$processes = @(Get-CimInstance Win32_Process)
if ($processes | Where-Object { $_.Name -eq 'MafioziPreview.exe' -and -not $_.ExecutablePath }) {
    throw 'Нельзя проверить путь уже запущенной игры. Новый экземпляр не создан.'
}
$existingPreview = $processes | Where-Object {
    $executable = $_.ExecutablePath
    $command = if ($_.CommandLine) { $_.CommandLine.Replace('/', '\') } else { '' }
    $isRelease = $executable -and $_.Name -eq 'MafioziPreview.exe' -and
        $executable.StartsWith($exportRoot, [StringComparison]::OrdinalIgnoreCase)
    $isEditorRun = $executable -and
        [IO.Path]::GetDirectoryName($executable) -eq $engineDirectory -and
        $_.Name -match '^Godot_v4\.7\.2-stable_win64(?:_console)?\.exe$' -and
        $command.IndexOf($projectRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0
    ($isRelease -or $isEditorRun) -and $command -notmatch '(?:^|\s)(?:--headless|--editor|--project-manager|-e)(?:\s|$)'
}
if ($existingPreview) {
    Write-Output 'Сцена уже открыта. Дополнительный экземпляр не запущен.'
    $existingPreview | Select-Object ProcessId, Name
    return
}
if ($CheckOnly) {
    Write-Output 'Открытая сцена не найдена. Проверка завершена без запуска.'
    return
}
Start-Process -FilePath $GodotExe -ArgumentList @('--path', ('"' + $projectRoot + '"')) -WindowStyle Normal
