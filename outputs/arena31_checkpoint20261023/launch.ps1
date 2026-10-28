$ErrorActionPreference = 'Stop'
$gameSolid29 = Join-Path $PSScriptRoot 'game'
$engineSolid29 = Join-Path $env:LOCALAPPDATA 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
$outSolid29 = Join-Path $PSScriptRoot ('interactive/' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
New-Item -ItemType Directory -Path $outSolid29 -Force | Out-Null
$argsSolid29 = @('--path', ('"' + $gameSolid29 + '"'), 'res://scenes/arena27.tscn', '--windowed', '--resolution', '1440x900', '--max-fps', '60', '--', ('"--lab-out=' + $outSolid29 + '"'))
$processSolid29 = Start-Process -FilePath $engineSolid29 -ArgumentList $argsSolid29 -WorkingDirectory $gameSolid29 -WindowStyle Normal -RedirectStandardOutput (Join-Path $outSolid29 'stdout.log') -RedirectStandardError (Join-Path $outSolid29 'stderr.log') -PassThru
$receiptSolid29 = [ordered]@{pid=$processSolid29.Id; game=$gameSolid29; scene='res://scenes/arena27.tscn'; output=$outSolid29; started=$processSolid29.StartTime.ToString('o')}
$receiptSolid29 | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'OPENED.json') -Encoding utf8
$receiptSolid29 | ConvertTo-Json -Compress
