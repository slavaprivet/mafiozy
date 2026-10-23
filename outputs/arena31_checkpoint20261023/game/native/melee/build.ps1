$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$cache = Join-Path $repo 'outputs/tools/llvm-mingw-20260616-ucrt-x86_64'
$expectedArchive = 'b9b68a4d276e16fa25802aaba458e4638f64b3884c290aaccdc2d87083b6ca35'
if ((Get-FileHash -LiteralPath "$cache.zip").Hash.ToLower() -ne $expectedArchive) { throw 'Official pinned compiler archive mismatch' }
$pinned = @{
    'src/native.c' = 'c6a4a21a8b328f4cde4579f43d57b836af1e5554aaa594e863f20c0dfed0c4ad'
    'src/kernel.h' = '34bcdaa050cd186ea00b5b407d332f46421bc7e48c1a01afd406469ab21a8090'
    'src/bulk_skin/native_skin.c' = '485a28d5117254d0d377fda495500ef48e0283f9638873589ba8e596e9a05b25'
    'src/gdextension_interface.h' = '640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'
}
foreach ($path in $pinned.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $path)).Hash.ToLower() -ne $pinned[$path]) { throw "Accepted numerical input changed: $path" }
}
$out = Join-Path $repo 'outputs/coordinator21_melee_combined/project'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$compiler = Join-Path $cache 'bin/x86_64-w64-mingw32-clang.exe'
$objectDir = Join-Path $repo 'outputs/coordinator21_melee_combined/objects'
New-Item -ItemType Directory -Force -Path $objectDir | Out-Null
$common = @('-std=c11','-O2','-fno-fast-math','-ffp-contract=off','-Wall','-Wextra','-Wno-unused-parameter')
$objects = @()
foreach ($unit in @(@{file='src/native.c';name='geometry';entry='melee_native_init'},@{file='src/bulk_skin/native_skin.c';name='skin';entry='melee_skin_init'})) {
    $raw = Join-Path $objectDir ($unit.name+'.raw.o')
    $object = Join-Path $objectDir ($unit.name+'.o')
    & $compiler @common -c (Join-Path $PSScriptRoot $unit.file) -o $raw
    if ($LASTEXITCODE -ne 0) { throw 'Accepted translation unit compile failed' }
    $metadata = & (Join-Path $cache 'bin/llvm-readobj.exe') --coff-directives $raw
    if ($LASTEXITCODE -ne 0) { throw 'COFF metadata inspection failed' }
    $directive = @($metadata | Where-Object { $_.StartsWith('Directive(s):') })
    if ($directive.Count -ne 1 -or $directive[0].Replace('Directive(s):','').Trim() -ne ('-export:'+$unit.entry)) { throw 'Unexpected accepted object linker metadata' }
    # Remove only the checked legacy dllexport directive, not code/data/symbols.
    # The exact accepted C stays intact, while the DLL exports one combined entry.
    & (Join-Path $cache 'bin/llvm-objcopy.exe') --remove-section=.drectve $raw $object
    if ($LASTEXITCODE -ne 0) { throw 'Legacy entry export metadata removal failed' }
    $objects += $object
}
$compileArgs = $common + @('-shared','-static','-Wl,--no-insert-timestamp','-Wl,--exclude-all-symbols',
    (Join-Path $PSScriptRoot 'src/combined.c')) + $objects + @('-o',(Join-Path $out 'melee_kernels.dll'))
& $compiler @compileArgs
if ($LASTEXITCODE -ne 0) { throw 'Combined compile/link failed' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'melee_kernels.gdextension.cfg') -Destination (Join-Path $out 'melee_kernels.gdextension')
@'
config_version=5
[application]
config/name="Isolated combined melee kernels"
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $out 'project.godot') -Encoding utf8
Get-FileHash -LiteralPath (Join-Path $out 'melee_kernels.dll')
