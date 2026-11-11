param([string]$PythonExecutable="python", [string]$FlutterExecutable="", [Alias("RebuildFrontend")][switch]$RebuildApp)
$ErrorActionPreference="Stop"
Set-Location -LiteralPath $PSScriptRoot
if (-not (Test-Path -LiteralPath ".venv\Scripts\python.exe")) {
    & $PythonExecutable -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw "Python 3.12+ with venv/pip is required." }
}
& .\.venv\Scripts\python.exe -m pip install -r requirements.lock.txt
if ($LASTEXITCODE -ne 0) { throw "Python dependency installation failed." }
if ($RebuildApp) {
    if (-not $FlutterExecutable) {
        $onPath = Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -First 1
        $candidates = @($onPath.Source, 'E:\tools\flutter\bin\flutter.bat', (Join-Path $env:LOCALAPPDATA 'flutter\bin\flutter.bat'))
        $FlutterExecutable = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    }
    if (-not $FlutterExecutable) { throw "Flutter SDK not found. Install Flutter stable (3.47+) and pass -FlutterExecutable, or put flutter on PATH." }
    Push-Location app
    try {
        & $FlutterExecutable pub get
        if ($LASTEXITCODE -ne 0) { throw "Flutter dependency installation failed." }
        & $FlutterExecutable build windows --release
        if ($LASTEXITCODE -ne 0) { throw "Flutter Windows build failed." }
    } finally { Pop-Location }
}
Write-Host "Ready. Run .\Start.ps1" -ForegroundColor Green
