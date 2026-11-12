param([string]$PythonExecutable="python", [string]$FlutterExecutable="", [Alias("RebuildFrontend")][switch]$RebuildApp)
$ErrorActionPreference="Stop"
Set-Location -LiteralPath $PSScriptRoot
$venvPython = ".venv\Scripts\python.exe"
$healthy = $false
if (Test-Path -LiteralPath $venvPython) {
    & $venvPython -m pip --version *> $null
    $healthy = ($LASTEXITCODE -eq 0)
}
if (-not $healthy) {
    # A half-created or broken virtual environment must be rebuilt, not reused.
    & $PythonExecutable -m venv .venv --clear
    if ($LASTEXITCODE -ne 0) { throw "Python 3.12+ with venv/pip is required." }
    if (-not (Test-Path -LiteralPath $venvPython)) { throw "Virtual environment was not created at .venv." }
}
& $venvPython -m pip install -r requirements.lock.txt
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
