param([switch]$CheckOnly, [switch]$Quiet)
# The castle shortcut and F5 resolve the same pinned current assembly.
$ErrorActionPreference = 'Stop'
$canonicalLauncher = Join-Path $PSScriptRoot 'godot/launch_current_game.ps1'
& $canonicalLauncher @PSBoundParameters
exit $LASTEXITCODE
