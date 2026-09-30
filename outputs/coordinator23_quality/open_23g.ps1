$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$taskExport=Join-Path $taskRoot 'godot/mafiozi_walk/exports/win64/s01-20260930-quality23g-play'
$taskExe=Join-Path $taskExport 'MafioziPreview.exe'
$taskPack=Join-Path $taskExport 'MafioziPreview.pck'
$taskExpectedPack='ae82e44c46cf3d5f420897c7e91d8a631691dbf4180d27c45342ff428916209e'
if((Get-FileHash -LiteralPath $taskPack).Hash.ToLowerInvariant() -ne $taskExpectedPack){throw 'Accepted PCK changed'}
if((Get-FileHash -LiteralPath $taskExe).Hash.ToLowerInvariant() -ne 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'){throw 'Accepted executable changed'}
$taskInventory=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'Godot|MafioziPreview'})
$taskGames=@($taskInventory | Where-Object {$_.ProcessId -ne 45268 -and $_.CommandLine -notmatch '--headless'})
if($taskGames.Count){throw 'An existing GPU process needs reconciliation; no second game launched'}
$taskLinkPath=Join-Path $taskRoot 'Мафиози — актуальная версия.lnk'
$taskLink=(New-Object -ComObject WScript.Shell).CreateShortcut($taskLinkPath)
$taskBefore=[ordered]@{path=$taskLinkPath;target=$taskLink.TargetPath;arguments=$taskLink.Arguments;working_directory=$taskLink.WorkingDirectory}
if($taskLink.TargetPath -ne (Join-Path $taskRoot 'godot/mafiozi_walk/exports/win64/s01-20260930-quality23e-play/MafioziPreview.exe')){throw 'User shortcut target changed; inspect first'}
$taskLink.TargetPath=$taskExe
$taskLink.WorkingDirectory=$taskExport
$taskLink.Arguments=''
$taskLink.Description='Мафиози 23g — окно багажника, оружие и физика попаданий'
$taskLink.Save()
# This is the one interactive game requested by the user, not a background helper.
$taskGame=Start-Process -FilePath $taskExe -WorkingDirectory $taskExport -PassThru
Start-Sleep -Milliseconds 3500
$taskGame.Refresh()
if($taskGame.HasExited){throw 'Accepted game exited after launch'}
$taskAfter=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'Godot|MafioziPreview'})
$taskRecord=[ordered]@{timestamp=(Get-Date -Format o);revision='s01-20260930-quality23g';pack_sha256=$taskExpectedPack;pid=$taskGame.Id;responding=$taskGame.Responding;path=$taskExe;shortcut_before=$taskBefore;shortcut_after=$taskLink.TargetPath;inventory_before=$taskInventory|Select-Object ProcessId,Name,CommandLine;inventory_after=$taskAfter|Select-Object ProcessId,Name,CommandLine}
$taskRecord|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $taskRoot 'outputs/coordinator23_delivery23g/RUNNING.json') -Encoding utf8
Write-Output ('Opened accepted23g PID '+$taskGame.Id)
