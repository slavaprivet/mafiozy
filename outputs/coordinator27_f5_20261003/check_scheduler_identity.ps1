$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot '../../tools/godot/launch_current_game.ps1'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Resolve-Path $launcher), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$functionAst = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-CurrentCooperativeProcess' }, $true)
if (-not $functionAst) { throw 'Missing scheduler identity predicate' }
& ([scriptblock]::Create($functionAst.Extent.Text + @'

$born = [DateTime]::UtcNow
$entry = [pscustomobject]@{ ProcessId=12345; CommandLine='godot --headless --path candidate'; ExecutablePath='C:\tools\godot.exe'; CreationDate=$born }
$good = @{pid=12345; command_line=$entry.CommandLine; executable_path=$entry.ExecutablePath; creation_filetime=[string]$born.ToFileTimeUtc()}
if (-not (Test-CurrentCooperativeProcess $entry @([pscustomobject]$good) $born)) { throw 'Valid registered diagnostic rejected' }
$cases = @{
    reused_pid = @{creation_filetime=[string]($born.AddSeconds(-1).ToFileTimeUtc())}
    changed_command = @{command_line='godot --path user_game'}
    changed_binary = @{executable_path='C:\other\godot.exe'}
    other_pid = @{pid=12346}
    missing_identity = @{creation_filetime=$null}
}
foreach ($name in $cases.Keys) {
    $bad = $good.Clone()
    foreach ($key in $cases[$name].Keys) { $bad[$key]=$cases[$name][$key] }
    if (Test-CurrentCooperativeProcess $entry @([pscustomobject]$bad) $born) { throw "Unsafe admission: $name" }
}
if (Test-CurrentCooperativeProcess $entry @() $born) { throw 'Unregistered process admitted' }
[pscustomobject]@{passed=$true; checks=7; engine_started=$false} | ConvertTo-Json -Compress
'@))
