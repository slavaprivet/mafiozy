param(
    [Parameter(Mandatory=$true)][string]$Resource,
    [ValidateRange(1,60)][int]$TimeoutSeconds=60
)
$ErrorActionPreference='Stop'
if($Resource -notmatch '^res://scripts/tests/test_transport_[a-z0-9_]+\.gd$'){ throw 'Only scoped transport tests are allowed' }
$workspace='C:/Users/Слава/Desktop/Мафиози'
$binary='C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
$logDirectory=Join-Path $workspace 'outputs/transport_headless'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$runName=($Resource.Split('/')[-1].Replace('.gd',''))+'-'+[guid]::NewGuid().ToString('N')
$stdout=Join-Path $logDirectory ($runName+'.stdout.txt')
$stderr=Join-Path $logDirectory ($runName+'.stderr.txt')
$process=Start-Process -FilePath $binary -ArgumentList @('--headless','--path','godot/mafiozi_walk','--script',$Resource) -WorkingDirectory $workspace -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if(-not $process.WaitForExit($TimeoutSeconds*1000)){
    $current=Get-CimInstance Win32_Process -Filter "ProcessId=$($process.Id)"
    if($current -and $current.ExecutablePath -eq $binary.Replace('/','\') -and $current.CommandLine -match '--headless' -and $current.CommandLine.Contains($Resource)){
        Stop-Process -Id $process.Id -Force
    }
    Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue
    Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue
    Write-Output "TRANSPORT_TEST_TIMEOUT pid=$($process.Id) logs=$stdout"
    exit 124
}
$process.WaitForExit()
Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue
Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue
exit $process.ExitCode
