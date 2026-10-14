$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$toolsCache = Join-Path $repo 'outputs/tools'
$name = 'llvm-mingw-20260616-ucrt-x86_64.zip'
$expected = 'b9b68a4d276e16fa25802aaba458e4638f64b3884c290aaccdc2d87083b6ca35'
$release = Invoke-RestMethod 'https://api.github.com/repos/mstorsjo/llvm-mingw/releases/tags/20260616'
$asset = @($release.assets | Where-Object name -eq $name)
if ($asset.Count -ne 1 -or $asset[0].digest -ne "sha256:$expected" -or $asset[0].size -ne 187504083) { throw 'Official asset metadata does not match pinned release' }
$url = 'https://github.com/mstorsjo/llvm-mingw/releases/download/20260616/' + $name
if ($asset[0].browser_download_url -ne $url) { throw 'Unexpected official asset URL' }
New-Item -ItemType Directory -Force -Path $toolsCache | Out-Null
$archive = Join-Path $toolsCache $name
if (-not (Test-Path -LiteralPath $archive)) { Invoke-WebRequest $url -OutFile $archive }
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLower() -ne $expected) { throw 'Compiler archive failed published SHA256 verification; nothing extracted or executed' }
$directory = Join-Path $toolsCache 'llvm-mingw-20260616-ucrt-x86_64'
if (-not (Test-Path -LiteralPath $directory)) { Expand-Archive -LiteralPath $archive -DestinationPath $toolsCache }
Write-Output "Verified portable compiler cache: $directory"
