$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$out=Join-Path $repo 'outputs/coordinator24_delivery24a'
$dest=Join-Path $repo 'godot/mafiozi_walk/exports/win64/s01-20260930-quality24a-play'
$exe=Join-Path $dest 'MafioziPreview.exe'
$pack=Join-Path $dest 'MafioziPreview.pck'
$expectedPack='634b9d3b48e4502538331da9b9e9efdb1641cfc83f04c40c65bd592bd4db7dd5'
$expectedExe='d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'
if((Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedPack){throw 'PCK mismatch'}
if((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedExe){throw 'EXE mismatch'}
$gpuOwners=@(Get-CimInstance Win32_Process | Where-Object {
 $_.Name -eq 'MafioziPreview.exe' -or ($_.Name -match '^Godot.*\.exe$' -and $_.CommandLine -match '--(main-pack|path|script)' -and $_.CommandLine -notmatch '--headless')
})
if($gpuOwners.Count){throw ('Review existing game first: '+($gpuOwners.ProcessId -join ','))}
$shortcutPath=Join-Path $repo 'Мафиози — актуальная версия.lnk'
if(-not (Test-Path -LiteralPath $shortcutPath)){throw 'Expected project shortcut missing'}
$link=(New-Object -ComObject WScript.Shell).CreateShortcut($shortcutPath)
$old=Join-Path $repo 'godot/mafiozi_walk/exports/win64/s01-20260930-quality23h-play/MafioziPreview.exe'
if($link.TargetPath -ne $old -or $link.Arguments -ne ''){throw 'Shortcut changed concurrently'}
Copy-Item -LiteralPath $shortcutPath -Destination (Join-Path $out 'before-shortcut.lnk')
$play=Start-Process -FilePath $exe -WorkingDirectory $dest -WindowStyle Normal -PassThru
Start-Sleep -Seconds 4
$play.Refresh()
if($play.HasExited -or -not $play.Responding){throw 'New user game did not become responsive'}
$link.TargetPath=$exe
$link.WorkingDirectory=$dest
$link.Description='Мафиози 24a — исправлено управление после взятия оружия из багажника'
$link.Save()
$verify=(New-Object -ComObject WScript.Shell).CreateShortcut($shortcutPath)
if($verify.TargetPath -ne $exe){throw 'Shortcut update did not persist'}
$record=[ordered]@{opened_at=(Get-Date).ToString('o');pid=$play.Id;responding=$play.Responding;exe=$exe;exe_sha256=$expectedExe;pack_sha256=$expectedPack;shortcut=$shortcutPath;shortcut_target=$verify.TargetPath;scope='Exact accepted cargo24a, one user gameplay process; pre-existing ProjectManager retained'}
$record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $out 'OPENED24A.json') -Encoding utf8
$record | ConvertTo-Json -Depth 4
