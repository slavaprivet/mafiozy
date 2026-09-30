$ErrorActionPreference = 'Stop'
$root23 = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$base23 = Join-Path $root23 'outputs\artist23_point23e\package\MafioziPreview.pck'
$after23 = Join-Path $root23 'outputs\coordinator23_quality\candidate08\godot\mafiozi_walk\exports\win64\s01-20260930-quality23f\MafioziPreview.pck'
$restore23 = Join-Path (Split-Path $base23) 'MafioziPreview.exe'
$engine23 = Join-Path $env:LOCALAPPDATA 'MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$beforeHash23 = 'ec737f864181031e574bc4eb9e179a6d70cf3be6282a6068371b388b25167179'
$afterHash23 = '710f2d40d852c4181d874494294ef236e6bc2d215ab216b4c016ad92e82c3c72'
if ((Get-FileHash -LiteralPath $base23 -Algorithm SHA256).Hash.ToLowerInvariant() -ne $beforeHash23) { throw 'Baseline changed' }
if ((Get-FileHash -LiteralPath $after23 -Algorithm SHA256).Hash.ToLowerInvariant() -ne $afterHash23) { throw 'Candidate changed' }
$inventory23 = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' })
$inventory23 | Select-Object ProcessId,ExecutablePath,CommandLine | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'gpu_before_inventory.json') -Encoding UTF8
$game23 = @($inventory23 | Where-Object { $_.ProcessId -eq 48272 -and $_.ExecutablePath -eq $restore23 })
$other23 = @($inventory23 | Where-Object { $_.ProcessId -notin @(45268,48272) })
if ($game23.Count -ne 1 -or $other23.Count -ne 0) { throw 'Fresh inventory differs; do not stop or launch blindly' }
$closed23 = $false
try {
    $process23 = Get-Process -Id 48272
    [void]$process23.CloseMainWindow()
    if (-not $process23.WaitForExit(5000)) { $process23.Kill(); $process23.WaitForExit() }
    $closed23 = $true
    foreach ($side23 in @('baseline','candidate')) {
        $active23 = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' -and $_.ProcessId -ne 45268 })
        if ($active23.Count -ne 0) { throw 'GPU slot no longer exclusive' }
        $pack23 = if ($side23 -eq 'baseline') { $base23 } else { $after23 }
        $hash23 = if ($side23 -eq 'baseline') { $beforeHash23 } else { $afterHash23 }
        $out23 = Join-Path $PSScriptRoot ('gpu_' + $side23 + '01')
        if (Test-Path -LiteralPath $out23) { throw 'Do not overwrite previous run' }
        & python (Join-Path $PSScriptRoot 'run_capture.py') --engine $engine23 --pack $pack23 --expected-sha $hash23 --side $side23 --out $out23 --run-gpu
        if ($LASTEXITCODE -ne 0) { throw ('GPU ' + $side23 + ' failed') }
    }
    & python (Join-Path $PSScriptRoot 'compare.py') (Join-Path $PSScriptRoot 'gpu_baseline01\RESULT.json') (Join-Path $PSScriptRoot 'gpu_candidate01\RESULT.json') (Join-Path $PSScriptRoot 'GPU_COMPARISON01.json')
} finally {
    if ($closed23) {
        $active23 = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Mafiozi' -and $_.ProcessId -ne 45268 })
        if ($active23.Count -eq 0) {
            # Restore the user's interactive game; a visible window is intentional.
            $restored23 = Start-Process -FilePath $restore23 -WorkingDirectory (Split-Path $restore23) -PassThru
            @{ processId=$restored23.Id; executable=$restore23; pck=$beforeHash23 } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'RESTORED_GAME.json') -Encoding UTF8
        } else { Write-Warning 'A game is still active; refused to create a second GPU game' }
    }
}
