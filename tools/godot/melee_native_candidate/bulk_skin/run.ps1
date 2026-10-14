$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$engine='C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$out=Join-Path $repo 'outputs/coordinator21_melee_native_skin'
& (Join-Path $PSScriptRoot 'build.ps1')
foreach ($case in @(@{path=(Join-Path $repo 'godot/mafiozi_walk');script='capture_skin.gd';log='capture.log'},@{path=(Join-Path $out 'project');script='verify_skin.gd';log='verify.log'})) {
    $log=Join-Path $out $case.log
    & $engine --headless --path $case.path --script (Join-Path $PSScriptRoot $case.script) --quit-after 600 *> $log
    $code=$LASTEXITCODE
    if ($code -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw "Skin prototype failed; see $log" }
}
$report=Get-Content -LiteralPath (Join-Path $out 'report.json') -Raw | ConvertFrom-Json
if (-not $report.passed -or $report.poses.Count -ne 22) { throw 'Full actual skin report not accepted' }
$report | Select-Object checks,passed,original_loop_us,engine_bulk_groups_us,native_plus_frame_pack_us | ConvertTo-Json -Depth 4
