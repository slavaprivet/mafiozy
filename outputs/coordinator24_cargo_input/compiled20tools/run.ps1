param(
 [switch]$Gpu,
 [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$Run='headless01',
 [ValidateRange(10,60)][int]$MaxSeconds=45
)
$ErrorActionPreference='Stop'
$repo='C:/Users/Слава/Desktop/Мафиози'
$project=Join-Path $repo 'outputs/coordinator24_quality/candidate20/godot/mafiozi_walk'
$export=Join-Path $project 'exports/win64/s01-20260930-quality24a'
$pack=Join-Path $export 'MafioziPreview.pck'
$receiptPath=Join-Path $export 'build_receipt.json'
$engine='C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$scriptPath=Join-Path $PSScriptRoot 'test_compiled.gd'
$out=Join-Path (Split-Path -Parent $PSScriptRoot) ('compiled20_'+$Run)
$expected='634b9d3b48e4502538331da9b9e9efdb1641cfc83f04c40c65bd592bd4db7dd5'
foreach($path in @($engine,$pack,$receiptPath,$scriptPath)){
 if(-not (Test-Path -LiteralPath $path)){throw ('Missing '+$path)}
 if($path.Contains('"')){throw 'Unexpected quote in launcher path'}
}
if(Test-Path -LiteralPath $out){throw ('Use a new Run name; preserving '+$out)}
$receipt=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
$artifact=@($receipt.artifacts | Where-Object {$_.filename -eq 'MafioziPreview.pck'})
if($artifact.Count -ne 1 -or $artifact[0].sha256 -ne $expected){throw 'Receipt does not identify exact frozen20 PCK'}
$packSha=(Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash.ToLowerInvariant()
if($packSha -ne $expected){throw 'Exact frozen20 PCK SHA mismatch'}
if(@($receipt.inputs).Count -ne 209 -or -not $receipt.sourceInputsUnchangedDuringExport){throw 'Expected209 frozen source inputs'}
$inputFailures=@()
foreach($inputRow in $receipt.inputs){
 $inputPath=Join-Path $project $inputRow.path
 if(-not (Test-Path -LiteralPath $inputPath)){ $inputFailures+=($inputRow.path+':missing');continue }
 $inputHash=(Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
 if($inputHash -ne $inputRow.sha256){$inputFailures+=($inputRow.path+':sha')}
}
if($inputFailures.Count){throw ('Frozen source mismatch: '+($inputFailures -join ', '))}
$gpuOwners=@(Get-CimInstance Win32_Process | Where-Object {
 $_.Name -eq 'MafioziPreview.exe' -or ($_.Name -match '^Godot.*\.exe$' -and $_.CommandLine -match '--(main-pack|path|script)' -and $_.CommandLine -notmatch '--headless')
})
if($gpuOwners.Count){throw ('A gameplay/GPU process exists; coordinator must inventory it before this run: '+(($gpuOwners.ProcessId) -join ','))}
New-Item -ItemType Directory -Path $out | Out-Null
$argsList=@('--main-pack',('"'+$pack+'"'),'--script',('"'+$scriptPath+'"'),'--resolution','1280x720')
if(-not $Gpu){$argsList+=@('--headless','--fixed-fps','60')}
$argsList+=@('--','--compiled-candidate',('"--qa-out='+$out+'"'),('--expected-sha='+$expected),('"--exact-pack='+$pack+'"'))
if($Gpu){$argsList+='--gpu'}
$pre=[ordered]@{mode=$(if($Gpu){'focused_gpu'}else{'headless'});expected_pack_sha256=$expected;receipt_sha256=(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant();harness_sha256=(Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash.ToLowerInvariant();verified_source_inputs=209;command=@($engine)+$argsList;window=$(if($Gpu){'normal focused on-screen; no NO_FOCUS/offscreen flags'}else{'headless'});max_seconds=$MaxSeconds;scope='single exact compiled PCK; no resource overrides; original3NPC/8buildings/377collision; top_level aiming fixture; no whole-city perf claim'}
$pre | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $out 'RUN_PRE.json') -Encoding utf8
$windowStyle=if($Gpu){'Normal'}else{'Hidden'}
$qa=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle $windowStyle -PassThru -RedirectStandardOutput (Join-Path $out 'stdout.log') -RedirectStandardError (Join-Path $out 'stderr.log')
$watch=[Diagnostics.Stopwatch]::StartNew();$timedOut=$false
while(-not $qa.HasExited -and $watch.Elapsed.TotalSeconds -lt $MaxSeconds){$qa.WaitForExit(500)|Out-Null;$qa.Refresh()}
if(-not $qa.HasExited){$timedOut=$true;$qa.Kill();$qa.WaitForExit();$qa.Refresh()}
$postSha=(Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash.ToLowerInvariant()
$resultPath=Join-Path $out 'RESULT.json'
$result=if(Test-Path -LiteralPath $resultPath){Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json}else{$null}
$stderr=Get-Content -LiteralPath (Join-Path $out 'stderr.log') -Raw -ErrorAction SilentlyContinue
$nativeErrors=[bool]($stderr -match '(?m)(SCRIPT ERROR|ERROR:|Parse Error|Assertion failed)')
$success=(-not $timedOut) -and $postSha -eq $expected -and $null -ne $result -and $result.valid -eq $true -and -not $nativeErrors
$runResult=[ordered]@{passed=$success;pid=$qa.Id;seconds=$watch.Elapsed.TotalSeconds;timed_out=$timedOut;exit_code=$qa.ExitCode;pack_unchanged=$postSha -eq $expected;native_errors=$nativeErrors;result=$result}
$runResult | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $out 'RUN.json') -Encoding utf8
$runResult | Select-Object passed,pid,seconds,timed_out,exit_code,native_errors | ConvertTo-Json
Get-Content -LiteralPath (Join-Path $out 'stdout.log') -Tail 4
if($stderr){Write-Output $stderr}
if(-not $success){throw ('Compiled20 acceptance failed; inspect '+$out)}
