# Install at tools/godot/launch_minimap_demo.ps1 in the repository.
# Opens the standalone demo editor; its first import completes before F5.
param(
    [Alias('GodotExe')][string]$GodotPath = $env:GODOT_EXE,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$project = Join-Path $repo 'godot/minimap_demo'
$config = Join-Path $project 'project.godot'
$scene = Join-Path $project 'scenes/demo.tscn'
$lockPath = Join-Path $repo 'docs/godot/ENGINE_LOCK.json'
foreach ($required in @($config, $scene, $lockPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required demo file missing: $required"
    }
}
if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Pass -GodotPath with the installed Godot executable, or set GODOT_EXE.'
}
$engine = (Resolve-Path -LiteralPath $GodotPath).Path
$lock = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 | ConvertFrom-Json
$expected = [string]$lock.editor.gui.sha256
if ($expected -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash -ine $expected) {
    throw 'Godot executable does not match docs/godot/ENGINE_LOCK.json.'
}
$projectText = Get-Content -LiteralPath $config -Raw -Encoding UTF8
$application = [regex]::Match($projectText, '(?ms)^\[application\]\s*\r?\n(.*?)(?=^\[|\z)')
$entries = [regex]::Matches($application.Groups[1].Value, '(?m)^run/main_scene\s*=\s*"([^"\r\n]+)"\s*$')
if ($entries.Count -ne 1 -or $entries[0].Groups[1].Value -cne 'res://scenes/demo.tscn') {
    throw 'Standalone demo main scene is not res://scenes/demo.tscn; review the candidate.'
}
if ($CheckOnly) {
    [ordered]@{ status='PREFLIGHT_ONLY'; project=$project; entry='res://scenes/demo.tscn'; engine=$engine; engine_sha256=$expected; runtime='NOT_RUN' } | ConvertTo-Json
    return
}
# A visible editor is the purpose of this user-invoked launcher. It imports
# missing .godot cache itself; F5 applies only to this standalone project.
Start-Process -FilePath $engine -ArgumentList @('--editor', '--path', ('"' + $project + '"')) -WorkingDirectory $project -WindowStyle Normal
