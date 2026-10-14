$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$cache = Join-Path $repo 'outputs/tools/llvm-mingw-20260616-ucrt-x86_64'
$archive = "$cache.zip"
$expected = 'b9b68a4d276e16fa25802aaba458e4638f64b3884c290aaccdc2d87083b6ca35'
if ((Get-FileHash -LiteralPath $archive).Hash.ToLower() -ne $expected) { throw 'Pinned official compiler archive digest mismatch' }
$out = Join-Path $repo 'outputs/coordinator21_melee_native/project'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$compiler = Join-Path $cache 'bin/x86_64-w64-mingw32-clang.exe'
& $compiler --version
& $compiler -std=c11 -O2 -fno-fast-math -ffp-contract=off -Wall -Wextra -Wno-unused-parameter -shared -static '-Wl,--no-insert-timestamp' (Join-Path $PSScriptRoot 'native.c') -o (Join-Path $out 'melee_native.dll')
if ($LASTEXITCODE -ne 0) { throw 'Native candidate compile failed' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'candidate.gdextension') -Destination $out
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'project.godot') -Destination $out
Copy-Item -LiteralPath (Join-Path $repo 'godot/mafiozi_walk/scripts/combat/melee_triangle_contact.gd') -Destination (Join-Path $out 'reference.gd')
Copy-Item -LiteralPath (Join-Path $repo 'godot/mafiozi_walk/scripts/tests/fixtures/melee_triangle_oracle.json') -Destination (Join-Path $out 'oracle.json')
Get-FileHash -LiteralPath (Join-Path $out 'melee_native.dll')
