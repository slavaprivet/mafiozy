param(
    [ValidateSet('prepare','mock','baseline','live','status','test')]
    [string]$Mode = 'prepare'
)
$ErrorActionPreference = 'Stop'
$runtimeRoot = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies'
$pythonPath = Join-Path $runtimeRoot 'python\python.exe'
$nodePath = Join-Path $runtimeRoot 'node\bin\node.exe'
if (-not (Test-Path -LiteralPath $pythonPath)) { throw 'Bundled Python runtime is unavailable.' }
if ($Mode -eq 'test') {
    & $pythonPath -m unittest discover -s $PSScriptRoot -p 'test_pipeline.py' -v
} elseif ($Mode -eq 'live') {
    # Entered locally, hidden. Never stored in a file, command argument or transcript.
    $keySecure = Read-Host 'DeepSeek API key (hidden; session only)' -AsSecureString
    $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keySecure)
    $previousKey = $env:DEEPSEEK_API_KEY
    try {
        $env:DEEPSEEK_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
        & $pythonPath (Join-Path $PSScriptRoot 'pipeline.py') live
    } finally {
        $env:DEEPSEEK_API_KEY = $previousKey
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
        $keySecure.Dispose()
    }
} else {
    & $pythonPath (Join-Path $PSScriptRoot 'pipeline.py') $Mode --node $nodePath
}
exit $LASTEXITCODE
