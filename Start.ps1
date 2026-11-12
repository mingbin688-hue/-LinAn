param(
    [string]$PythonExecutable = "",
    [string]$HostAddress = "127.0.0.1",
    [ValidateRange(1024,65535)][int]$Port = 8765,
    [string]$Database = "",
    [switch]$Background,
    [switch]$OpenApp
)
$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

# Probe through a reachable address even when uvicorn binds every interface.
$probeHost = if ($HostAddress -in @('0.0.0.0', '::', '[::]')) { '127.0.0.1' } else { $HostAddress }
if ($probeHost.Contains(':') -and -not $probeHost.StartsWith('[')) { $probeHost = "[$probeHost]" }
$url = "http://${probeHost}:$Port"
if ($Database) {
    $Database = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $Database))
    New-Item -ItemType Directory -Path (Split-Path -Parent $Database) -Force | Out-Null
    $env:LINAN_DB = $Database
}
$databaseLabel = if ($Database) { $Database } else { "runtime\linan.sqlite3" }

function Test-Linan {
    try {
        $response = Invoke-RestMethod -Uri "$url/api/health" -TimeoutSec 2
        return ($response.status -eq 'ok' -and $response.app -eq 'linan-community-guard')
    } catch { return $false }
}

$appExe = Join-Path $PSScriptRoot "app/build/windows/x64/runner/Release/linan_app.exe"
function Start-LinanApp {
    if (Test-Path -LiteralPath $appExe) { Start-Process -FilePath $appExe; return $true }
    Write-Warning "Windows app is not built yet. Run Setup.ps1 -RebuildApp first."
    return $false
}

if (Test-Linan) {
    Write-Host "Linan is already running: $url" -ForegroundColor Green
    if ($OpenApp) { [void](Start-LinanApp) }
    exit 0
}
if (-not $PythonExecutable) {
    $localPython = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
    $workspacePython = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\work\.venv\Scripts\python.exe"))
    if (Test-Path -LiteralPath $localPython) { $PythonExecutable = $localPython }
    elseif (Test-Path -LiteralPath $workspacePython) { $PythonExecutable = $workspacePython }
    else { $PythonExecutable = "python" }
}
Write-Host "Linan: $url (database: $databaseLabel)" -ForegroundColor Green
if (-not $Background) {
    Write-Host "Press Ctrl+C to stop. Use -Background for persistent local operation."
    & $PythonExecutable -m uvicorn backend.main:app --host $HostAddress --port $Port
    exit $LASTEXITCODE
}

$runtime = Join-Path $PSScriptRoot 'runtime'
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
$stdout = Join-Path $runtime 'server.stdout.log'
$stderr = Join-Path $runtime 'server.stderr.log'
$pidFile = Join-Path $runtime 'server.json'
$pythonCommand = Get-Command $PythonExecutable -ErrorAction Stop
$serverProcess = Start-Process -FilePath $pythonCommand.Source -ArgumentList @('-m','uvicorn','backend.main:app','--host',$HostAddress,'--port',"$Port") -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$ready = $false
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    if (Test-Linan) { $ready = $true; break }
    $serverProcess.Refresh()
    if ($serverProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
}
if (-not $ready) {
    # Never leave a half-started server or a stale pid file behind.
    try { if (-not $serverProcess.HasExited) { $serverProcess.Kill($true); $serverProcess.WaitForExit(5000) } } catch {}
    if (Test-Path -LiteralPath $pidFile) { Remove-Item -LiteralPath $pidFile -Force }
    if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Tail 20 }
    throw "Linan did not become ready at $url. Check runtime/server.stderr.log. If port $Port is occupied, select another -Port."
}
$serverInfo = @{
    pid = $serverProcess.Id
    startedTicks = $serverProcess.StartTime.ToUniversalTime().Ticks.ToString()
    executable = $pythonCommand.Source
    url = $url
    project = $PSScriptRoot
    database = $databaseLabel
}
$serverInfo | ConvertTo-Json | Set-Content -LiteralPath $pidFile -Encoding UTF8
Write-Host "Linan is running in the background. Close this window safely. Stop it with Stop.ps1." -ForegroundColor Green
if ($OpenApp) { [void](Start-LinanApp) }
exit 0
