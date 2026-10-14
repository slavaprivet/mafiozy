$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$project = Join-Path $PSScriptRoot 'project'
$game = Join-Path $repo 'godot/mafiozi_walk'
$engine = 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$combined = Join-Path $repo 'outputs/coordinator21_melee_combined/project'
if ((Get-FileHash -LiteralPath (Join-Path $combined 'melee_kernels.dll') -Algorithm SHA256).Hash.ToLower() -ne 'a5695c0b117e42a4847d10cdef0f7b71485f6243a7f412b6d6cb0eb5924c2add') { throw 'Combined DLL changed' }
foreach ($directory in @('scripts/combat','scripts/tests','scripts/npc_visual','assets/npc_visual/session/prepared')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $project $directory) | Out-Null
}
foreach ($name in @('melee_native_query_adapter.gd','melee_skin_provider.gd','melee_contact_selection.gd','melee_triangle_contact.gd')) {
    Copy-Item -LiteralPath (Join-Path $game "scripts/combat/$name") -Destination (Join-Path $project "scripts/combat/$name")
}
foreach ($name in @('npc_visual_cache.gd','npc_visual_loader.gd','npc_float_color_bridge.gd')) {
    Copy-Item -LiteralPath (Join-Path $game "scripts/npc_visual/$name") -Destination (Join-Path $project "scripts/npc_visual/$name")
}
Copy-Item -LiteralPath (Join-Path $game 'scripts/tests/test_melee_native_query_adapter.gd') -Destination (Join-Path $project 'scripts/tests/test_melee_native_query_adapter.gd')
Copy-Item -LiteralPath (Join-Path $game 'assets/hero.glb') -Destination (Join-Path $project 'assets/hero.glb')
Get-ChildItem -LiteralPath (Join-Path $game 'assets/npc_visual/session/prepared') -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $project "assets/npc_visual/session/prepared/$($_.Name)")
}
foreach ($name in @('melee_kernels.dll','melee_kernels.gdextension')) {
    Copy-Item -LiteralPath (Join-Path $combined $name) -Destination (Join-Path $project $name)
}
Set-Content -LiteralPath (Join-Path $project 'project.godot') -Encoding utf8 -Value @('config_version=5','[application]','config/name="Isolated native query adapter test"','[rendering]','renderer/rendering_method="gl_compatibility"')
& $engine --headless --path $project --editor --import --quit 2>&1 | Tee-Object -FilePath (Join-Path $PSScriptRoot 'import.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $PSScriptRoot 'import.log') -Pattern 'SCRIPT ERROR|ERROR:')) { throw 'Isolated import failed' }
& $engine --headless --path $project --script res://scripts/tests/test_melee_native_query_adapter.gd --quit-after 240 2>&1 | Tee-Object -FilePath (Join-Path $PSScriptRoot 'run.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $PSScriptRoot 'run.log') -Pattern 'SCRIPT ERROR|ERROR:')) { throw 'Isolated adapter checks failed' }
$report = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'report.json') -Raw | ConvertFrom-Json
if (-not $report.passed) { throw 'Adapter report did not pass' }
