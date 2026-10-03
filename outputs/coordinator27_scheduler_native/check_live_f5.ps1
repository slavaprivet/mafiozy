param([Parameter(Mandatory=$true)][int[]]$ExpectedPid)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$launcher=Join-Path $root 'tools/godot/launch_current_game.ps1'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($launcher,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
$names=@('Get-CurrentTestProcesses','Test-CurrentCooperativeProcess')
$definitions=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in $names},$true)
. ([scriptblock]::Create(($definitions | ForEach-Object {$_.Extent.Text}) -join "`n"))
$registered=@(Get-CurrentTestProcesses (Join-Path $root 'tools/godot/test_scheduler.py'))
foreach($testPid in $ExpectedPid){
    $entry=Get-CimInstance Win32_Process -Filter "ProcessId=$testPid"
    $process=Get-Process -Id $testPid
    if(-not (Test-CurrentCooperativeProcess $entry $registered $process.StartTime)){throw "F5 rejects registered diagnostic $testPid"}
}
[pscustomobject]@{passed=$true; admitted=$ExpectedPid; user_game_started=$false} | ConvertTo-Json -Compress
