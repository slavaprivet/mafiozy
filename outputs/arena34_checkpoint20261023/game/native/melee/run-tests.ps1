param([switch]$SkipBuild)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$engine='C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$out=Join-Path $repo 'outputs/coordinator21_melee_combined'
$project=Join-Path $out 'project'
if (-not $SkipBuild) { & (Join-Path $PSScriptRoot 'build.ps1') }
Copy-Item -LiteralPath (Join-Path $repo 'godot/mafiozi_walk/scripts/combat/melee_triangle_contact.gd') -Destination (Join-Path $project 'reference.gd')
New-Item -ItemType Directory -Force -Path (Join-Path $project 'scripts/combat') | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'godot/mafiozi_walk/scripts/combat/melee_triangle_contact.gd') -Destination (Join-Path $project 'scripts/combat/melee_triangle_contact.gd')
Copy-Item -LiteralPath (Join-Path $repo 'godot/mafiozi_walk/scripts/tests/fixtures/melee_triangle_oracle.json') -Destination (Join-Path $project 'oracle.json')
foreach ($case in @(
    @{path=(Join-Path $repo 'godot/mafiozi_walk');script='capture_geometry.gd'},
    @{path=(Join-Path $repo 'godot/mafiozi_walk');script='capture_skin.gd'},
    @{path=$project;script='verify_geometry.gd'},
    @{path=$project;script='verify_skin.gd'},
    @{path=$project;script='combined_lifecycle.gd'})) {
    $log=Join-Path $out ($case.script+'.log')
    & $engine --headless --path $case.path --script (Join-Path $PSScriptRoot ('tests/'+$case.script)) --quit-after 600 *> $log
    $code=$LASTEXITCODE
    if ($code -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw "Combined test failed; see $log" }
}
foreach ($file in @('geometry_report.json','skin_report.json','lifecycle_report.json')) {
    $report=Get-Content -LiteralPath (Join-Path $out $file) -Raw | ConvertFrom-Json
    if (-not $report.passed) { throw "Failed report $file" }
    Write-Output "$file : $($report.checks) PASS"
}
