[CmdletBinding()]
param(
    [string]$EngineDirectory = (Join-Path $env:LOCALAPPDATA 'MafioziTools\Godot-4.7.2'),
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
    [string]$Label = ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')),
    [switch]$PrepareTemplates,
    [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$projectPath = Join-Path $repoRoot 'godot\mafiozi_walk'
$lockPath = Join-Path $repoRoot 'docs\godot\ENGINE_LOCK.json'
$engineLock = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 | ConvertFrom-Json
$enginePath = Join-Path $EngineDirectory $engineLock.editor.console.filename
$engineGuiPath = Join-Path $EngineDirectory $engineLock.editor.gui.filename
$templateRoot = Join-Path $env:APPDATA ('Godot\export_templates\' + $engineLock.templates.version)

function Assert-LockedFile([string]$Path, [long]$Bytes, [string]$Sha256) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Locked file missing: $Path" }
    if ((Get-Item -LiteralPath $Path).Length -ne $Bytes) { throw "Locked length mismatch: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Sha256.ToLowerInvariant()) { throw "Locked SHA-256 mismatch: $Path" }
}

function Read-ExportPackDirectory([string]$Path) {
    # Godot 4.7.2 core/io/file_access_pack.cpp: PCK v2/v3/v4 directory layout.
    # This only reads the pack. It does not run the exported executable or scene.
    $reader = [IO.BinaryReader]::new([IO.File]::OpenRead($Path))
    try {
        if ($reader.ReadUInt32() -ne 0x43504447) { throw 'Not a standalone Godot PCK' }
        $format = $reader.ReadUInt32()
        if ($format -notin @(2, 3, 4)) { throw "Unsupported PCK format $format" }
        $major = $reader.ReadUInt32(); $minor = $reader.ReadUInt32(); $patch = $reader.ReadUInt32()
        if ($major -ne 4 -or $minor -ne 7 -or $patch -ne 2) { throw "Unexpected PCK engine $major.$minor.$patch" }
        $flags = $reader.ReadUInt32()
        if ($flags -notin @(0, 2)) { throw 'Encrypted or sparse export is not admitted by S01' }
        [void]$reader.ReadUInt64()
        if ($format -ge 3) {
            $directoryOffset = $reader.ReadUInt64()
            if ($directoryOffset -ge $reader.BaseStream.Length) { throw 'PCK directory is out of range' }
            $reader.BaseStream.Position = $directoryOffset
        } else { $reader.BaseStream.Position += 64 }
        $count = $reader.ReadUInt32()
        if ($count -gt 10000) { throw 'Unexpectedly large S01 PCK directory' }
        $paths = [Collections.Generic.List[string]]::new()
        for ($index = 0; $index -lt $count; $index++) {
            $length = $reader.ReadUInt32()
            if ($length -lt 1 -or $length -gt 4096) { throw 'Invalid PCK path length' }
            $entryPath = [Text.Encoding]::UTF8.GetString($reader.ReadBytes($length)).TrimEnd([char]0)
            [void]$reader.ReadUInt64(); [void]$reader.ReadUInt64(); [void]$reader.ReadBytes(16)
            $entryFlags = $reader.ReadUInt32()
            if ($entryFlags -ne 0) { throw "Unexpected PCK entry flags: $entryPath" }
            if ($entryPath -match '(^|/)(test_[^/]*|tests|debug_harness|outputs|exports)(/|$)' -or
                $entryPath -match 'export_credentials|(^|/)\.env($|\.)|user://' -or $entryPath.Contains('..')) {
                throw "Excluded harness or unsafe file reached PCK: $entryPath"
            }
            $paths.Add($entryPath)
        }
        if (-not ($paths -contains 'res://data/block.json' -or $paths -contains 'data/block.json')) {
            throw 'The runtime block JSON is missing from PCK'
        }
        if (-not ($paths | Where-Object { $_ -match '(^|/)scripts/main\.(gd|gdc|gd\.remap)$' })) {
            throw 'The main runtime script is missing from PCK'
        }
        return [ordered]@{ format = $format; fileCount = $count; excludedHarnessesAbsent = $true; paths = @($paths) }
    } finally { $reader.Dispose() }
}

Assert-LockedFile $enginePath $engineLock.editor.console.bytes $engineLock.editor.console.sha256
Assert-LockedFile $engineGuiPath $engineLock.editor.gui.bytes $engineLock.editor.gui.sha256
$version = (& $enginePath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne $engineLock.versionString) {
    throw "Expected $($engineLock.versionString), got $version"
}

if ($PrepareTemplates) {
    $archive = Join-Path $EngineDirectory $engineLock.templates.archive.filename
    if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        Write-Host "Downloading official matching templates ($($engineLock.templates.archive.bytes) bytes)."
        $part = $archive + '.download'
        Invoke-WebRequest -Uri $engineLock.templates.archive.url -OutFile $part
        Assert-LockedFile $part $engineLock.templates.archive.bytes $engineLock.templates.archive.sha256
        Move-Item -LiteralPath $part -Destination $archive
    }
    Assert-LockedFile $archive $engineLock.templates.archive.bytes $engineLock.templates.archive.sha256
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $versionEntry = $zip.GetEntry('templates/version.txt')
        if ($null -eq $versionEntry) { throw 'Official template archive has no version.txt' }
        $reader = [IO.StreamReader]::new($versionEntry.Open())
        try { $templateVersion = $reader.ReadToEnd().Trim() } finally { $reader.Dispose() }
        if ($templateVersion -ne $engineLock.templates.version) { throw "Wrong template version: $templateVersion" }
        [IO.Directory]::CreateDirectory($templateRoot) | Out-Null
        foreach ($entryLock in $engineLock.templates.files) {
            $destination = Join-Path $templateRoot $entryLock.filename
            if (-not ([IO.Path]::GetFullPath($destination).StartsWith([IO.Path]::GetFullPath($templateRoot) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
                throw 'Unsafe template destination in engine lock'
            }
            if (Test-Path -LiteralPath $destination) {
                Assert-LockedFile $destination $entryLock.bytes $entryLock.sha256
                continue
            }
            $entry = $zip.GetEntry('templates/' + $entryLock.filename)
            if ($null -eq $entry) { throw "Missing archive entry: $($entryLock.filename)" }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $false)
            Assert-LockedFile $destination $entryLock.bytes $entryLock.sha256
        }
    } finally { $zip.Dispose() }
}

foreach ($entryLock in $engineLock.templates.files) {
    Assert-LockedFile (Join-Path $templateRoot $entryLock.filename) $entryLock.bytes $entryLock.sha256
}
if ($VerifyOnly) {
    Write-Host "Verified exact engine $version and matching Windows x86_64 templates. No game launched."
    exit 0
}

$exportRoot = [IO.Path]::GetFullPath((Join-Path $projectPath 'exports\win64'))
$outputDirectory = [IO.Path]::GetFullPath((Join-Path $exportRoot $Label))
if (-not $outputDirectory.StartsWith($exportRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Export target escapes the project exports directory'
}
if (Test-Path -LiteralPath $outputDirectory) { throw "Choose a new -Label; output already exists: $outputDirectory" }
[IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
$exePath = Join-Path $outputDirectory 'MafioziPreview.exe'
$logPath = Join-Path $outputDirectory 'export.log'

# Record the inputs before export; never read user://, save files or credentials.
$inputPaths = @((Join-Path $projectPath 'project.godot'), (Join-Path $projectPath 'export_presets.cfg'))
$presetText = Get-Content -LiteralPath (Join-Path $projectPath 'export_presets.cfg') -Raw
$selectedMode = $presetText -match 'export_filter="resources"'
$selectedPaths = @([regex]::Matches(($presetText -split "`n" | Where-Object { $_ -match '^export_files=' }), '"res://([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$includeFilters = (([regex]::Match($presetText, 'include_filter="([^"]*)"')).Groups[1].Value).Split(',')
if ($selectedMode) {
    # Selected-resource exports do not reliably collect GDScript literal loads.
    # Fail before export if a selected runtime script references an omitted one.
    # This deliberately does not admit every WIP script in the shared project.
    foreach ($selectedScript in ($selectedPaths | Where-Object { $_.EndsWith('.gd') })) {
        $selectedText = Get-Content -LiteralPath (Join-Path $projectPath $selectedScript) -Raw
        foreach ($dependency in [regex]::Matches($selectedText, 'res://scripts/[^"\s]+\.gd')) {
            $dependencyPath = $dependency.Value.Substring(6)
            $included = @($includeFilters | Where-Object { $dependencyPath -like $_ }).Count -gt 0
            if ($selectedPaths -notcontains $dependencyPath -and -not $included) {
                throw "Runtime dependency omitted from export: $selectedScript -> $dependencyPath"
            }
        }
    }
}
foreach ($directory in @('scripts', 'scenes', 'data', 'assets')) {
    $inputPaths += @(Get-ChildItem -LiteralPath (Join-Path $projectPath $directory) -File -Recurse |
        Where-Object {
            $relative = $_.FullName.Substring($projectPath.Length + 1).Replace('\', '/')
            $selected = -not $selectedMode -or $selectedPaths -contains $relative -or
                ($_.Extension -eq '.import' -and $selectedPaths -contains $relative.Substring(0, $relative.Length - 7))
            $included = @($includeFilters | Where-Object { $relative -like $_ }).Count -gt 0
            $_.Name -notlike 'test_*' -and $_.Extension -ne '.uid' -and ($selected -or $included)
        } |
        ForEach-Object { $_.FullName })
}
$inputReceipts = @($inputPaths | Sort-Object -Unique | ForEach-Object {
    [ordered]@{ path = $_.Substring($projectPath.Length + 1).Replace('\', '/'); bytes = (Get-Item -LiteralPath $_).Length; sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() }
})

Write-Host "Exporting release artifact headlessly to $outputDirectory"
& $enginePath --headless --path $projectPath --log-file $logPath --export-release 'Windows Desktop S01' $exePath
if ($LASTEXITCODE -ne 0) { throw "Godot export failed; inspect $logPath" }
if (Select-String -LiteralPath $logPath -Pattern '^(SCRIPT ERROR:|SHADER ERROR:|ERROR:)' -Quiet) {
    throw "Godot reported an error even though the process exited successfully; inspect $logPath"
}
foreach ($sourceInput in $inputReceipts) {
    Assert-LockedFile (Join-Path $projectPath $sourceInput.path) $sourceInput.bytes $sourceInput.sha256
}
$packPath = [IO.Path]::ChangeExtension($exePath, '.pck')
if (-not (Test-Path -LiteralPath $exePath) -or -not (Test-Path -LiteralPath $packPath)) {
    throw 'Expected executable and PCK were not both generated'
}
$packInventory = Read-ExportPackDirectory $packPath
foreach ($sourceInput in $inputReceipts) {
    $relative = $sourceInput.path
    if ($relative.EndsWith('.gd') -and
        $packInventory.paths -notcontains $relative -and
        $packInventory.paths -notcontains ([IO.Path]::ChangeExtension($relative, '.gdc').Replace('\', '/'))) {
        throw "Selected runtime script missing from PCK: $relative"
    }
    if ($relative.StartsWith('data/') -and $packInventory.paths -notcontains $relative) {
        throw "Selected runtime data missing from PCK: $relative"
    }
    if ($relative.EndsWith('.glb') -and $packInventory.paths -notcontains ($relative + '.import')) {
        throw "Selected asset import missing from PCK: $relative"
    }
}
$artifacts = @(Get-ChildItem -LiteralPath $outputDirectory -File | Where-Object { $_.Name -ne 'export.log' } | ForEach-Object {
    [ordered]@{ filename = $_.Name; bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$receipt = [ordered]@{
    schema = 'mafiozi.godot.export-receipt/v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    engineVersion = $version
    engineLockSha256 = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash.ToLowerInvariant()
    exportScriptSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    preset = 'Windows Desktop S01'
    mode = 'release'
    architecture = 'x86_64'
    sourceInputsUnchangedDuringExport = $true
    launched = $false
    gameplayAccepted = $false
    packInventory = $packInventory
    inputs = $inputReceipts
    artifacts = $artifacts
}
$receiptPath = Join-Path $outputDirectory 'build_receipt.json'
$receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
Write-Host "Release artifact created. No executable or GPU run performed. Receipt: $receiptPath"
