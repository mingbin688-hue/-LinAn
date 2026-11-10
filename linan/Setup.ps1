param([string]$PythonExecutable="python", [switch]$RebuildFrontend)
$ErrorActionPreference="Stop"
Set-Location -LiteralPath $PSScriptRoot
if (-not (Test-Path -LiteralPath ".venv\Scripts\python.exe")) {
    & $PythonExecutable -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw "Python 3.12+ with venv/pip is required." }
}
& .\.venv\Scripts\python.exe -m pip install -r requirements.lock.txt
if ($LASTEXITCODE -ne 0) { throw "Python dependency installation failed." }
if ($RebuildFrontend) {
    Push-Location frontend
    try {
        if (Get-Command pnpm -ErrorAction SilentlyContinue) {
            & pnpm install --frozen-lockfile
            if ($LASTEXITCODE -ne 0) { throw "Frontend dependency installation failed." }
            & pnpm run build
        } elseif (Get-Command npm -ErrorAction SilentlyContinue) {
            & npm install
            if ($LASTEXITCODE -ne 0) { throw "Frontend dependency installation failed." }
            & npm run build
        } else { throw "Node.js 22+ and npm/pnpm are required to rebuild the frontend." }
        if ($LASTEXITCODE -ne 0) { throw "Frontend build failed." }
    } finally { Pop-Location }
}
Write-Host "Ready. Run .\Start.ps1" -ForegroundColor Green
