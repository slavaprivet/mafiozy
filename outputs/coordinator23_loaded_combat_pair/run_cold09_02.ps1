$ErrorActionPreference = 'Stop'
$root23 = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$engine23 = Join-Path $env:LOCALAPPDATA 'MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$cacheRoot23 = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'MafioziGodotPreview'))
$inventory23 = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' })
$inventory23 | Select-Object ProcessId,ExecutablePath,CommandLine | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'cold09_inventory02.json') -Encoding UTF8
$restore23 = Join-Path $root23 'outputs\artist23_head23e\package_direction\MafioziPreview.exe'
$restorePack23 = Join-Path (Split-Path $restore23) 'MafioziPreview.pck'
$restoreHash23 = '51e4dea55946d803a89f56633f3e61e1c94dcf777448b2287379eea3e817ae3e'
$games23 = @($inventory23 | Where-Object { $_.ProcessId -ne 45268 })
if ($games23.Count -ne 1 -or $games23[0].ProcessId -ne 9356 -or $games23[0].ExecutablePath -ne $restore23) { throw 'Fresh game identity differs; do not close blindly' }
if ((Get-FileHash -LiteralPath $restorePack23 -Algorithm SHA256).Hash.ToLowerInvariant() -ne $restoreHash23) { throw 'Restore pack changed' }
$closed23 = $false
$saved23 = @()
$cacheLog23 = @()
function CheckedCachePath23([string]$Name) {
    $p23 = [IO.Path]::GetFullPath((Join-Path $cacheRoot23 $Name))
    if ([IO.Path]::GetDirectoryName($p23) -ne $cacheRoot23) { throw 'Cache target escaped explicit game data directory' }
    return $p23
}
try {
    $process23 = Get-Process -Id 9356
    [void]$process23.CloseMainWindow()
    if (-not $process23.WaitForExit(5000)) { $process23.Kill(); $process23.WaitForExit() }
    $closed23 = $true
    foreach ($name23 in @('shader_cache','vulkan')) {
        $old23 = CheckedCachePath23 $name23
        $save23 = CheckedCachePath23 ($name23 + '.root23_original_1205')
        if (Test-Path -LiteralPath $save23) { throw 'Preserved cache already exists' }
        if (Test-Path -LiteralPath $old23) {
            Move-Item -LiteralPath $old23 -Destination $save23
            $saved23 += @{source=$old23; saved=$save23}
        }
    }
    foreach ($case23 in @('08','09')) {
        if (@(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' -and $_.ProcessId -ne 45268 }).Count -ne 0) { throw 'GPU no longer exclusive' }
        foreach ($name23 in @('shader_cache','vulkan')) { if (Test-Path -LiteralPath (CheckedCachePath23 $name23)) { throw 'Expected empty application shader/pipeline cache' } }
        $pack23 = Join-Path $root23 ("outputs\coordinator23_quality\candidate$case23\godot\mafiozi_walk\exports\win64\s01-20260930-quality23f\MafioziPreview.pck")
        $hash23 = if ($case23 -eq '08') { '710f2d40d852c4181d874494294ef236e6bc2d215ab216b4c016ad92e82c3c72' } else { '51892e6818d85edf4903362de225e4c71eaf262134df859c3c2a012751d5d83e' }
        $out23 = Join-Path $PSScriptRoot ('cold' + $case23 + '_02')
        if (Test-Path -LiteralPath $out23) { throw 'Fresh run directory required' }
        & python (Join-Path $PSScriptRoot 'run_capture.py') --engine $engine23 --pack $pack23 --expected-sha $hash23 --side candidate --out $out23 --run-gpu
        $exit23 = $LASTEXITCODE
        foreach ($name23 in @('shader_cache','vulkan')) {
            $generated23 = CheckedCachePath23 $name23
            $keep23 = CheckedCachePath23 ($name23 + '.root23_qa' + $case23 + '_1205')
            if (Test-Path -LiteralPath $keep23) { throw 'QA cache preservation target exists' }
            $exists23 = Test-Path -LiteralPath $generated23
            $files23 = if ($exists23) { @(Get-ChildItem -LiteralPath $generated23 -Recurse -File).Count } else { 0 }
            if ($exists23) { Move-Item -LiteralPath $generated23 -Destination $keep23 }
            $cacheLog23 += @{case=$case23; cache=$name23; original_absent_at_start=$true; created=$exists23; files=$files23; preserved=$keep23; exit=$exit23}
        }
        if ($exit23 -ne 0) { throw "Cold$case23 functional run failed" }
    }
    & python (Join-Path $PSScriptRoot 'compare.py') (Join-Path $PSScriptRoot 'cold08_02\RESULT.json') (Join-Path $PSScriptRoot 'cold09_02\RESULT.json') (Join-Path $PSScriptRoot 'COLD09_COMPARISON02.json')
    & python (Join-Path $root23 'outputs/coordinator23_head_visual08/run_capture.py') --pack (Join-Path $root23 'outputs/coordinator23_quality/candidate09/godot/mafiozi_walk/exports/win64/s01-20260930-quality23f/MafioziPreview.pck') --sha256 '51892e6818d85edf4903362de225e4c71eaf262134df859c3c2a012751d5d83e' --out (Join-Path $root23 'outputs/coordinator23_head_visual08/gpu09_01')
} finally {
    $cacheLog23 | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'COLD_CACHE_RECEIPT02.json') -Encoding UTF8
    $active23 = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' -and $_.ProcessId -ne 45268 })
    if ($active23.Count -eq 0) {
        foreach ($pair23 in $saved23) {
            if (Test-Path -LiteralPath $pair23.source) { throw 'Refuse to overwrite a generated cache during original restore' }
            Move-Item -LiteralPath $pair23.saved -Destination $pair23.source
        }
        if ($closed23) {
            $restored23 = Start-Process -FilePath $restore23 -WorkingDirectory (Split-Path $restore23) -PassThru
            @{processId=$restored23.Id; executable=$restore23; pck=$restoreHash23} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'RESTORED_HEAD_GAME02.json') -Encoding UTF8
        }
    } else { Write-Warning 'Engine active: original caches preserved in named backup, not moved underneath process' }
}

