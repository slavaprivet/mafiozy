$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$cache=Join-Path $repo 'outputs/tools/llvm-mingw-20260616-ucrt-x86_64'
if ((Get-FileHash -LiteralPath "$cache.zip").Hash.ToLower() -ne 'b9b68a4d276e16fa25802aaba458e4638f64b3884c290aaccdc2d87083b6ca35') { throw 'Pinned compiler archive mismatch' }
$out=Join-Path $repo 'outputs/coordinator21_melee_native_skin/project'
New-Item -ItemType Directory -Force -Path $out | Out-Null
& (Join-Path $cache 'bin/x86_64-w64-mingw32-clang.exe') -std=c11 -O2 -fno-fast-math -ffp-contract=off -Wall -Wextra -Wno-unused-parameter -shared -static '-Wl,--no-insert-timestamp' (Join-Path $PSScriptRoot 'native_skin.c') -o (Join-Path $out 'melee_skin.dll')
if ($LASTEXITCODE -ne 0) { throw 'Skin compile failed' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'skin.gdextension') -Destination $out
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../project.godot') -Destination $out
Get-FileHash -LiteralPath (Join-Path $out 'melee_skin.dll')
