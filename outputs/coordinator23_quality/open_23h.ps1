$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$taskDelivery=Join-Path $taskRoot 'outputs/coordinator23_delivery23h'
$taskPromotion=Get-Content -LiteralPath (Join-Path $taskDelivery 'PROMOTION.json') -Raw|ConvertFrom-Json
$taskExport=Join-Path $taskRoot $taskPromotion.export_path
$taskExe=Join-Path $taskExport 'MafioziPreview.exe'
$taskPack=Join-Path $taskExport 'MafioziPreview.pck'
if((Get-FileHash -LiteralPath $taskPack).Hash.ToLowerInvariant() -ne $taskPromotion.pack_sha256){throw 'Accepted PCK changed'}
$taskReceipt=Get-Content -LiteralPath (Join-Path $taskExport 'build_receipt.json') -Raw|ConvertFrom-Json
$taskExeSha=($taskReceipt.artifacts|Where-Object filename -eq 'MafioziPreview.exe').sha256
if((Get-FileHash -LiteralPath $taskExe).Hash.ToLowerInvariant() -ne $taskExeSha){throw 'Accepted executable changed'}
$taskInventory=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'Godot|MafioziPreview'})
$taskGames=@($taskInventory | Where-Object {$_.ProcessId -ne 45268 -and $_.CommandLine -notmatch '--headless'})
if($taskGames.Count){throw 'An existing GPU process needs reconciliation; no second game launched'}
$taskLinkPath=Join-Path $taskRoot 'Мафиози — актуальная версия.lnk'
$taskLink=(New-Object -ComObject WScript.Shell).CreateShortcut($taskLinkPath)
$taskBefore=[ordered]@{path=$taskLinkPath;target=$taskLink.TargetPath;arguments=$taskLink.Arguments;working_directory=$taskLink.WorkingDirectory}
if($taskLink.TargetPath -ne (Join-Path $taskRoot 'godot/mafiozi_walk/exports/win64/s01-20260930-quality23g-play/MafioziPreview.exe')){throw 'User shortcut changed; inspect first'}
$taskLink.TargetPath=$taskExe;$taskLink.WorkingDirectory=$taskExport;$taskLink.Arguments=''
$taskLink.Description='Мафиози 23h — подсветка оружия, удобный багажник и игровой курсор'
$taskLink.Save()
# The single interactive game explicitly requested by the user.
$taskGame=Start-Process -FilePath $taskExe -WorkingDirectory $taskExport -PassThru
Start-Sleep -Milliseconds 3500
$taskGame.Refresh()
if($taskGame.HasExited){throw 'Accepted game exited after launch'}
$taskAfter=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'Godot|MafioziPreview'})
[ordered]@{timestamp=(Get-Date -Format o);revision=$taskPromotion.revision;pack_sha256=$taskPromotion.pack_sha256;pid=$taskGame.Id;responding=$taskGame.Responding;path=$taskExe;shortcut_before=$taskBefore;shortcut_after=$taskLink.TargetPath;inventory_before=$taskInventory|Select-Object ProcessId,Name,CommandLine;inventory_after=$taskAfter|Select-Object ProcessId,Name,CommandLine}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $taskDelivery 'RUNNING.json') -Encoding utf8
Write-Output ('Opened accepted23h PID '+$taskGame.Id)
